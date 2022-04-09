#!/bin/bash

exec &> /var/log/userdata_on_reboot.$(date +"%Y%m%d%H%M%S").log
set -x

su - vaultwarden -c '
set -x
source ~/.profile
date > ~/reboot_time.log
cd application
docker compose build
docker compose up -d
set +x
'

set +x
