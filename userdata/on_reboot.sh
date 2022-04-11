#!/bin/bash

exec &> /var/log/userdata_on_reboot.$(date +"%Y%m%d%H%M%S").log
set -x

su - vaultwarden -c '
set -x
date > ${HOME}/reboot_time.log
cd ${HOME}/application
docker compose up -d
set +x
'

set +x
