locals {
  config_file = jsondecode(file("config.json"))
}

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 4.69.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
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
  description    = "Compartment for Terraform resources2."
  name           = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-compartment"
}

resource "oci_core_vcn" "vaultwarden_vcn" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  cidr_blocks = [
    "10.0.0.0/16"
  ]
  display_name = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-vcn"
}

resource "oci_core_internet_gateway" "vaultwarden_vcn_internet_gateway" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  vcn_id         = oci_core_vcn.vaultwarden_vcn.id
}

resource "oci_core_route_table" "vaultwarden_vcn_subnet_route_table" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  vcn_id         = oci_core_vcn.vaultwarden_vcn.id

  display_name = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-vcn-route-table"
  route_rules {
    network_entity_id = oci_core_internet_gateway.vaultwarden_vcn_internet_gateway.id
    destination       = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "vaultwarden_vcn_vaultwarden_subnet" {
  cidr_block     = "10.0.1.0/24"
  compartment_id = oci_identity_compartment.identity_compartment.id
  vcn_id         = oci_core_vcn.vaultwarden_vcn.id
  route_table_id = oci_core_route_table.vaultwarden_vcn_subnet_route_table.id
  security_list_ids = [
    oci_core_security_list.vaultwarden_vcn_vaultwarden_subnet_security_list.id
  ]
}

resource "oci_core_subnet" "vaultwarden_vcn_bastion_subnet" {
  cidr_block     = "10.0.2.0/24"
  compartment_id = oci_identity_compartment.identity_compartment.id
  vcn_id         = oci_core_vcn.vaultwarden_vcn.id
  route_table_id = oci_core_route_table.vaultwarden_vcn_subnet_route_table.id
  security_list_ids = [
    oci_core_security_list.vaultwarden_vcn_bastion_subnet_security_list.id
  ]
}

resource "oci_core_security_list" "vaultwarden_vcn_bastion_subnet_security_list" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  vcn_id         = oci_core_vcn.vaultwarden_vcn.id
  display_name   = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-vcn-bastion-subnet-security-list"
  egress_security_rules {
    protocol    = "6"
    destination = "${oci_core_instance.vaultwarden_instance.private_ip}/32"
  }
}


resource "oci_core_security_list" "vaultwarden_vcn_vaultwarden_subnet_security_list" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  vcn_id         = oci_core_vcn.vaultwarden_vcn.id
  display_name   = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-vcn-vaultwarden-subnet-security-list"
  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "10.0.2.0/24"
    description = "Ssh-bastion"
    tcp_options {
      max = 22
      min = 22
    }
  }


  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
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



resource "oci_objectstorage_bucket" "application" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  name           = "${lookup(local.config_file, "tf_prefix", "tf")}-application"
  namespace      = data.oci_objectstorage_namespace.object_storage_namespace.namespace
}

resource "oci_objectstorage_bucket" "vaultwarden_backups" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  name           = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-backups"
  namespace      = data.oci_objectstorage_namespace.object_storage_namespace.namespace
  versioning     = "Enabled"
}

resource "oci_objectstorage_object_lifecycle_policy" "vaultwarden_backups_lifecycle_policies" {
  bucket    = oci_objectstorage_bucket.vaultwarden_backups.name
  namespace = data.oci_objectstorage_namespace.object_storage_namespace.namespace
  rules {
    action      = "INFREQUENT_ACCESS"
    is_enabled  = true
    name        = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-backups-move-to-infrequent-access-after-7-days"
    target      = "previous-object-versions"
    time_amount = 7
    time_unit   = "DAYS"
  }
  rules {
    action      = "ARCHIVE"
    is_enabled  = true
    name        = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-backups-move-to-archive-after-21-days"
    target      = "previous-object-versions"
    time_amount = 21
    time_unit   = "DAYS"
  }
  rules {
    action      = "DELETE"
    is_enabled  = true
    name        = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-backups-delete-after-60-days"
    target      = "previous-object-versions"
    time_amount = 60
    time_unit   = "DAYS"
  }

}

variable "application_src_files" {
  type = list(string)
  default = [
    "application/Caddy-with-plugins/Dockerfile",
    "application/docker-compose.yml",
    "application/duck-dns-refresher/container_healthcheck.sh",
    "application/duck-dns-refresher/refresh_duck_dns.sh",
    "application/duck-dns-refresher/Dockerfile",
    "application/Caddy/Caddyfile",
    "application/vaultwarden-backup/container_healthcheck.sh",
    "application/vaultwarden-backup/vaultwarden_backup.sh",
    "application/vaultwarden-backup/setup_crontab.sh",
    "application/vaultwarden-backup/Dockerfile",
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
      content  = file(source.value)
      filename = source.value
    }
  }
  source {
    content  = data.template_file.docker_compose_env.rendered
    filename = "application/.env"
  }
}

resource "oci_objectstorage_object" "application_zip" {
  bucket    = oci_objectstorage_bucket.application.name
  content   = filebase64(data.archive_file.application_zip.output_path)
  namespace = data.oci_objectstorage_namespace.object_storage_namespace.namespace
  object    = "application.zip"
}

resource "oci_core_volume" "persistent_storage_volume" {
  compartment_id      = oci_identity_compartment.identity_compartment.id
  availability_domain = data.oci_identity_availability_domains.availability_domains.availability_domains[0].name
  size_in_gbs         = 50
  display_name        = "${lookup(local.config_file, "tf_prefix", "tf")}-persistent-storage"
}

resource "oci_core_volume_attachment" "persistent_storage_volume_attachment" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.vaultwarden_instance.id
  volume_id       = oci_core_volume.persistent_storage_volume.id
  device          = "/dev/oracleoci/oraclevdr"
  display_name    = "${oci_core_volume.persistent_storage_volume.display_name}-${oci_core_instance.vaultwarden_instance.display_name}-attachment"
}

resource "random_password" "instance_root_password" {
  length           = 24
  special          = false
  override_special = "!@#$%-_+:"
}
resource "random_string" "instance_root_password_salt" {
  length           = 16
  special          = false
  override_special = "!@#$%-_+:"
}

resource "oci_core_instance" "vaultwarden_instance" {
  availability_domain = data.oci_identity_availability_domains.availability_domains.availability_domains[0].name
  compartment_id      = oci_identity_compartment.identity_compartment.id
  shape               = local.config_file["instance_shape"]
  source_details {
    source_id   = "ocid1.image.oc1.eu-zurich-1.aaaaaaaajnd3h3nq2hotdp4hctcfgib5aaao6dx43jr6zu65bgtrour6b24q"
    source_type = "image"
  }

  agent_config {
    plugins_config {
      desired_state = "ENABLED"
      name          = "Bastion"
    }
  }

  display_name = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-on-ubuntu"
  create_vnic_details {
    assign_public_ip = true
    subnet_id        = oci_core_subnet.vaultwarden_vcn_vaultwarden_subnet.id
  }
  metadata = {
    user_data                    = base64encode(file("userdata/on_startup.sh"))
    user_data_on_init            = file("userdata/on_init.sh")
    user_data_on_reboot          = file("userdata/on_reboot.sh")
    application_bucket           = oci_objectstorage_bucket.application.name
    root_password_hash_secret_id = oci_vault_secret.root_password_hash_secret.id
  }

  preserve_boot_volume = false

  provisioner "local-exec" {
    command = "curl -sS 'https://www.duckdns.org/update?domains=${local.config_file["duck_dns_domain"]}&token=${local.config_file["duck_dns_token"]}&ip=${self.public_ip}'"
  }
}

resource "oci_identity_dynamic_group" "vaultwarden_instance_dynamic_group" {
  compartment_id = local.config_file["root_compartment_id"]
  description    = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-instance-dynamic-group"
  matching_rule  = "Any { instance.id = '${oci_core_instance.vaultwarden_instance.id}' }"
  name           = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-instance-dynamic-group"
}

resource "oci_identity_policy" "vaultwarden_instance_dynamic_group_policy" {
  compartment_id = local.config_file["root_compartment_id"]
  description    = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-instance-dynamic-group-policy"
  name           = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-instance-dynamic-group-policy"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.vaultwarden_instance_dynamic_group.name} to read objects in tenancy where target.bucket.name='${oci_objectstorage_bucket.application.name}'",
    "Allow dynamic-group ${oci_identity_dynamic_group.vaultwarden_instance_dynamic_group.name} to read objects in tenancy where target.bucket.name='${oci_objectstorage_bucket.vaultwarden_backups.name}'",
    "Allow dynamic-group ${oci_identity_dynamic_group.vaultwarden_instance_dynamic_group.name} to manage objects in tenancy where target.bucket.name='${oci_objectstorage_bucket.vaultwarden_backups.name}'",
    "Allow dynamic-group ${oci_identity_dynamic_group.vaultwarden_instance_dynamic_group.name} to read secret-bundles in tenancy where target.secret.id='${oci_vault_secret.root_password_hash_secret.id}'",
  ]
}

resource "oci_kms_key" "vaultwarden_kms_key" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  display_name   = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-kms-key"
  key_shape {
    algorithm = "AES"
    length    = "32"
  }
  management_endpoint = data.oci_kms_vault.vaultwarden_kms_vault.management_endpoint
}

data "external" "root_password_hash" {
  program = ["scripts/sha512_crypt.sh", "${random_string.instance_root_password_salt.result}", random_password.instance_root_password.result]
  query = {
    salt     = random_string.instance_root_password_salt.result
    password = random_password.instance_root_password.result
  }
}

resource "oci_vault_secret" "root_password_secret" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  key_id         = oci_kms_key.vaultwarden_kms_key.id
  secret_content {
    content_type = "BASE64"
    content      = sensitive(base64encode(random_password.instance_root_password.result))
  }

  secret_name = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-root-password"
  vault_id    = data.oci_kms_vault.vaultwarden_kms_vault.id
}

resource "oci_vault_secret" "root_password_hash_secret" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  key_id         = oci_kms_key.vaultwarden_kms_key.id
  secret_content {
    content_type = "BASE64"
    content      = sensitive(base64encode(data.external.root_password_hash.result.hash))
  }

  secret_name = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-root-password-hash"
  vault_id    = data.oci_kms_vault.vaultwarden_kms_vault.id
}

resource "oci_bastion_bastion" "vaultwarden_ssh_bastion" {
    bastion_type = "STANDARD"
    compartment_id = oci_identity_compartment.identity_compartment.id
    target_subnet_id = oci_core_subnet.vaultwarden_vcn_bastion_subnet.id
    client_cidr_block_allow_list = [
        "0.0.0.0/0"
    ]
    max_session_ttl_in_seconds = 3600
    name = "${lookup(local.config_file, "tf_prefix", "tf")}-vaultwarden-ssh-bastion"
}
