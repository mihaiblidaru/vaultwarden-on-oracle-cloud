locals {
    config_file = yamldecode(file("config.yml"))
}

terraform {
  required_providers {
    oci = {
        source = "oracle/oci"
        version = "~> 4.69.0"
    }
    tls = {
        source = "hashicorp/tls"
        version = "~> 3.1.0"
    }
    archive = {
        source = "hashicorp/archive"
        version = "~> 2.2.0"
    }
  }
}

provider "oci" {
  region = local.config_file["region"]
}

data "oci_objectstorage_namespace" "object_storage_namespace" {
}

resource "oci_identity_compartment" "identity_compartment" {
    compartment_id = local.config_file["root_compartment_id"]
    description = "Compartment for Terraform resources."
    name = "vaultwarden-compartment"
}

resource "oci_core_vcn" "vaultwarden_vcn" {
    compartment_id = oci_identity_compartment.identity_compartment.id
    cidr_blocks = [
        "10.0.0.0/16"
    ]
    display_name = "${lookup(local.config_file, "tf-prefix", "tf")}-vaultwarden-vcn"
}

resource "oci_core_internet_gateway" "vaultwarden_vcn_internet_gateway" {
    compartment_id = oci_identity_compartment.identity_compartment.id
    vcn_id = oci_core_vcn.vaultwarden_vcn.id
}

resource "oci_core_route_table" "vaultwarden_vcn_subnet_route_table" {
    compartment_id = oci_identity_compartment.identity_compartment.id
    vcn_id = oci_core_vcn.vaultwarden_vcn.id

    display_name = "${lookup(local.config_file, "tf-prefix", "tf")}-vaultwarden-vcn-route-table"
    route_rules {
        network_entity_id = oci_core_internet_gateway.vaultwarden_vcn_internet_gateway.id
        cidr_block = "0.0.0.0/0"
    }
}

resource "oci_core_subnet" "vaultwarden_vcn_subnet" {
    cidr_block = "10.0.1.0/24"
    compartment_id = oci_identity_compartment.identity_compartment.id
    vcn_id = oci_core_vcn.vaultwarden_vcn.id
    route_table_id = oci_core_route_table.vaultwarden_vcn_subnet_route_table.id
    security_list_ids = [
      oci_core_security_list.vaultwarden_vcn_subnet_security_list.id
    ]
}

resource "oci_core_security_list" "vaultwarden_vcn_subnet_security_list" {
    compartment_id = oci_identity_compartment.identity_compartment.id
    vcn_id = oci_core_vcn.vaultwarden_vcn.id
    display_name = "${lookup(local.config_file, "tf-prefix", "tf")}-vaultwarden-vcb-subnet-security-list"
    egress_security_rules {
        protocol = "6"
        destination = "0.0.0.0/0"
    }

    ingress_security_rules {
        protocol = "6"
        source = "0.0.0.0/0"
        description = "Ssh"
        tcp_options {
            max = 22
            min = 22
        }
    }

    ingress_security_rules {
        protocol = "6"
        source = "0.0.0.0/0"
        description = "HTTP"
        tcp_options {
            max = 80
            min = 80
        }
    }

    ingress_security_rules {
        protocol = "6"
        source = "0.0.0.0/0"
        description = "HTTPs"
        tcp_options {
            max = 443
            min = 443
        }
    }
}

data "oci_identity_availability_domains" "availability_domains" {
  compartment_id = oci_identity_compartment.identity_compartment.id
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "oci_objectstorage_bucket" "userdata" {
    compartment_id = oci_identity_compartment.identity_compartment.id
    name = "userdata"
    namespace = data.oci_objectstorage_namespace.object_storage_namespace.namespace
}

resource "oci_objectstorage_bucket" "application" {
    compartment_id = oci_identity_compartment.identity_compartment.id
    name = "application"
    namespace = data.oci_objectstorage_namespace.object_storage_namespace.namespace
}

variable "application_src_files" {
    type = list(string)
    default = [
      "application/Caddy-with-plugins/Dockerfile",
      "application/docker-compose.yml",
      "application/duck-dns-refresher/container_healthcheck.sh",
      "application/duck-dns-refresher/refresh_duck_dns.sh",
      "application/duck-dns-refresher/Dockerfile",
      "application/Caddy/Caddyfile"
    ]
}

data "template_file" "docker_compose_env" {
  template = templatefile("application/docker-compose.env.template", { config_yml = local.config_file })
}

data "archive_file" "application_zip" {
    type        = "zip"
    output_path = "application.zip"

    dynamic "source" {
        for_each = var.application_src_files
        content {
            content = file(source.value)
            filename = source.value
        }
    }
    source {
      content = data.template_file.docker_compose_env.rendered
      filename = "application/.env"
    }
}

resource "oci_objectstorage_object" "application_zip" {
    bucket = oci_objectstorage_bucket.application.name
    content = filebase64(data.archive_file.application_zip.output_path)
    namespace = data.oci_objectstorage_namespace.object_storage_namespace.namespace
    object = "application.zip"
}


resource "oci_objectstorage_object" "on_init" {
    bucket = oci_objectstorage_bucket.userdata.name
    content = file("userdata/on_init.sh")
    namespace = data.oci_objectstorage_namespace.object_storage_namespace.namespace
    object = "on_init.sh"
}

resource "oci_objectstorage_object" "on_reboot" {
    bucket = oci_objectstorage_bucket.userdata.name
    content = file("userdata/on_reboot.sh")
    namespace = data.oci_objectstorage_namespace.object_storage_namespace.namespace
    object = "on_reboot.sh"
}

resource "oci_core_volume" "persistent_storage_volume" {
    compartment_id = oci_identity_compartment.identity_compartment.id
    availability_domain = data.oci_identity_availability_domains.availability_domains.availability_domains[0].name
    size_in_gbs = 50
    display_name = "${lookup(local.config_file, "tf-prefix", "tf")}-persistent-storage"
}

resource "oci_core_volume_attachment" "persistent_storage_volume_attachment" {
    attachment_type = "paravirtualized"
    instance_id = oci_core_instance.vaultwarden_instance.id
    volume_id = oci_core_volume.persistent_storage_volume.id
    device = "/dev/oracleoci/oraclevdr"
    display_name = "${oci_core_volume.persistent_storage_volume.display_name}-${oci_core_instance.vaultwarden_instance.display_name}-attachment"
}

data "oci_core_images" "test_images" {
    compartment_id = oci_identity_compartment.identity_compartment.id
}

output "aaaaaa" {
    value = data.oci_core_images.test_images.images
}

resource "oci_core_instance" "vaultwarden_instance" {
    availability_domain = data.oci_identity_availability_domains.availability_domains.availability_domains[0].name
    compartment_id = oci_identity_compartment.identity_compartment.id
    shape = local.config_file["instance-shape"]
    source_details {
        source_id =   "ocid1.image.oc1.eu-zurich-1.aaaaaaaajnd3h3nq2hotdp4hctcfgib5aaao6dx43jr6zu65bgtrour6b24q"
        source_type = "image"
    }

    display_name = "${lookup(local.config_file, "tf-prefix", "tf")}-vaultwarden-on-ubuntu"
    create_vnic_details {
        assign_public_ip = true
        subnet_id = oci_core_subnet.vaultwarden_vcn_subnet.id
    }
    metadata = {
      ssh_authorized_keys = tls_private_key.ssh_key.public_key_openssh
      user_data = base64encode(file("userdata/on_startup.sh"))
    }

    preserve_boot_volume = false

    provisioner "local-exec" {
        command = "curl -sS 'https://www.duckdns.org/update?domains=${local.config_file["duck_dns_domain"]}&token=${local.config_file["duck_dns_token"]}&ip=${self.public_ip}'"
    }
}

resource "oci_identity_dynamic_group" "vaultwarden_instance_dynamic_group" {
    compartment_id = local.config_file["root_compartment_id"]
    description = "vaultwarden-instance-dynamic-group"
    matching_rule = "Any { instance.id = '${oci_core_instance.vaultwarden_instance.id}' }"
    name =  "vaultwarden-instance-dynamic-group"
}

resource "oci_identity_policy" "vaultwarden_instance_dynamic_group_policy" {
    compartment_id = local.config_file["root_compartment_id"]
    description = "vaultwarden-instance-dynamic-group-policy"
    name = "vaultwarden-instance-dynamic-group-policy"
    statements = [
        "Allow dynamic-group ${oci_identity_dynamic_group.vaultwarden_instance_dynamic_group.name} to read buckets in tenancy where target.bucket.name='${oci_objectstorage_bucket.userdata.name}'",
        "Allow dynamic-group ${oci_identity_dynamic_group.vaultwarden_instance_dynamic_group.name} to read objects in tenancy where target.bucket.name='${oci_objectstorage_bucket.userdata.name}'",
        "Allow dynamic-group ${oci_identity_dynamic_group.vaultwarden_instance_dynamic_group.name} to read buckets in tenancy where target.bucket.name='${oci_objectstorage_bucket.application.name}'",
        "Allow dynamic-group ${oci_identity_dynamic_group.vaultwarden_instance_dynamic_group.name} to read objects in tenancy where target.bucket.name='${oci_objectstorage_bucket.application.name}'",
    ]
}
resource "oci_kms_key" "vaultwarden_kms_key" {
    compartment_id = oci_identity_compartment.identity_compartment.id
    display_name = "${lookup(local.config_file, "tf-prefix", "tf")}-vaultwarden-kms-key"
    key_shape {
        algorithm = "AES"
        length = "32"
    }
    management_endpoint = oci_kms_vault.vaultwarden_kms_vault.management_endpoint
}

resource "oci_kms_vault" "vaultwarden_kms_vault" {
    compartment_id = oci_identity_compartment.identity_compartment.id
    display_name = "${lookup(local.config_file, "tf-prefix", "tf")}-vaultwarden-kms-vault"
    vault_type = "DEFAULT"
}

resource "oci_vault_secret" "ssh_key_secret" {
    compartment_id = oci_identity_compartment.identity_compartment.id
    key_id = oci_kms_key.vaultwarden_kms_key.id
    secret_content {
      content_type = "BASE64"
      content = base64encode(tls_private_key.ssh_key.private_key_pem)
      name = "vaultwarden-ssh-key"
    }

    secret_name = "${lookup(local.config_file, "tf-prefix", "tf")}-vaultwarden-ssh-key"
    vault_id = oci_kms_vault.vaultwarden_kms_vault.id
}

output "public_ip" {
    value = oci_core_instance.vaultwarden_instance.public_ip
}
