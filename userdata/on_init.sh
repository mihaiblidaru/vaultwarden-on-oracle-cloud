#!/bin/bash
exec &> >(tee -a "/var/log/userdata_on_init.log")
set -x

# Add vaultwarden user as soon as posible to allow login trough bastion
useradd -m vaultwarden -s /bin/bash

# Upgrade all packages
apt-get upgrade -y

# Install docker and utilities
apt-get install -y \
  docker.io \
  zip \
  unzip

# Add docker group
groupadd docker

# Add user to docker group
usermod -aG docker vaultwarden

export OCI_CLI_AUTH=instance_principal

# Set root password
ROOT_PASSWORD_HASH_SECRET_ID=$(curl -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/root_password_hash_secret_id)
usermod -p $(oci secrets secret-bundle get --secret-id ${ROOT_PASSWORD_HASH_SECRET_ID} --query 'data."secret-bundle-content".content' --raw-output | base64 -d) root

# Install ssh public key
su - vaultwarden -c '
mkdir -p ${HOME}/.ssh
curl -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/ssh_authorized_keys > ${HOME}/.ssh/authorized_keys
'

# Remove ubuntu default user
userdel -rf ubuntu

# Install docker compose for vaultwarden user
su - vaultwarden -c '
mkdir -p ${HOME}/.docker/cli-plugins/
wget -q https://github.com/docker/compose/releases/download/v2.4.0/docker-compose-linux-x86_64 -O ${HOME}/.docker/cli-plugins/docker-compose
chmod +x ${HOME}/.docker/cli-plugins/docker-compose
'

# Export
su - vaultwarden -c '
cat << EOF >> ${HOME}/.profile
export OCI_CLI_AUTH=instance_principal
EOF
'

# Mount persistent filesystem
NUM_PARTITIONS=$(partx -g /dev/oracleoci/oraclevdr | wc -l)

if [ "${NUM_PARTITIONS}" == 0 ]; then
  parted /dev/oracleoci/oraclevdr --script mklabel gpt
  parted -a optimal /dev/oracleoci/oraclevdr --script mkpart primary ext4 2048 100%
  mkfs.ext4 /dev/oracleoci/oraclevdr1
  mkdir -p /mnt/permanent_storage/
fi

echo "/dev/oracleoci/oraclevdr1 /mnt/permanent_storage/ ext4 defaults,_netdev,nofail 0 2" >> /etc/fstab

mount -a

# Download application 
su - vaultwarden -c '
set -x
cd $HOME
export APPLICATION_BUCKET=$(curl -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/application_bucket)
oci os object get --bucket-name ${APPLICATION_BUCKET} --name application.zip --file - | base64 -d > application.zip
unzip -o application.zip
set +x
'

# Download application 
su - vaultwarden -c '
set -x
cd $HOME/application
docker compose pull
docker compose build
set +x
'

set +x
