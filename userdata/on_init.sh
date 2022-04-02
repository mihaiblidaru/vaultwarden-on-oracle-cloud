#!/bin/bash
exec &> >(tee -a "/var/log/userdata_on_init.log")
set -x

apt-get install -y \
  docker.io \
  zip \
  unzip

groupadd docker
usermod -aG docker ubuntu

su - ubuntu -c '
mkdir -p ~/.docker/cli-plugins/
wget -q https://github.com/docker/compose/releases/download/v2.4.0/docker-compose-linux-x86_64 -O ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
'

export OCI_CLI_AUTH=instance_principal

su - ubuntu -c '
cat << EOF >> /home/ubuntu/.profile
export OCI_CLI_AUTH=instance_principal
export GID=$(id -g)
EOF
'

su - ubuntu -c '
set -x
source ~/.profile
cd $HOME
oci os object get --bucket-name application --name application.zip --file - | base64 -d > application.zip
unzip -o application.zip
set +x
'

set +x
