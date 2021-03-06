#!/bin/bash
exec &> /var/log/userdata_on_startup.log
set -x
apt-get update -y
apt-get install python3-pip -y

pip3 install oci_cli

mkdir -p /opt/userdata/

export OCI_CLI_AUTH=instance_principal

while true
do
    oci iam region list > /dev/null 2>&1

    if [ "$?" == "0" ]; then
        break
    fi

    sleep 5
done

oci os object get --bucket-name userdata --name on_init.sh --file /opt/userdata/on_init.sh
oci os object get --bucket-name userdata --name on_reboot.sh --file /opt/userdata/on_reboot.sh

chmod 744 /opt/userdata/on_init.sh
chmod 744 /opt/userdata/on_reboot.sh

cat << EOF > /etc/systemd/system/user-data-on-reboot.service
[Unit]
Description=Run on reboot userdata script
After=network.service

[Service]
ExecStart=/opt/userdata/on_reboot.sh

[Install]
WantedBy=default.target
EOF

chmod 664 /etc/systemd/system/user-data-on-reboot.service
systemctl daemon-reload
systemctl enable user-data-on-reboot.service

bash -x /opt/userdata/on_init.sh

apt-get upgrade -y

reboot

set +x
