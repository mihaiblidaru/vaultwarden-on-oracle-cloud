#!/bin/bash
exec &> /var/log/userdata_on_startup.log
set -x
apt-get update -y
apt-get install python3-pip -y

pip3 install oci_cli

mkdir -p /opt/userdata/

export OCI_CLI_AUTH=instance_principal
export USER_DATA_BUCKET=$(curl -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/user_data_bucket)
while true
do
    oci iam region list > /dev/null 2>&1

    if [ "$?" == "0" ]; then
        break
    fi

    sleep 5
done

curl -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/user_data_on_init > /opt/userdata/on_init.sh
curl -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/user_data_on_reboot > /opt/userdata/on_reboot.sh

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

reboot

set +x
