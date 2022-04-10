#!/bin/bash
set -x

URL=$1
VAULTWARDEN_DATA_DIR=$2
BUCKET_NAME=$3

# Create tmp directories for backups
BACKUP_DIR=$(mktemp -d /tmp/backup.XXXXXX)
mkdir -p ${BACKUP_DIR}/files

# Dump postgres database
pg_dump ${URL} -f ${BACKUP_DIR}/files/db.sql

# Attachments
[ -d ${VAULTWARDEN_DATA_DIR}/attachments/ ] && cp -r ${VAULTWARDEN_DATA_DIR}/attachments/ ${BACKUP_DIR}/files/attachments/

# Sends
[ -d ${VAULTWARDEN_DATA_DIR}/sends/ ] && cp -r ${VAULTWARDEN_DATA_DIR}/sends/ ${BACKUP_DIR}/files/sends/

# Config
[ -f ${VAULTWARDEN_DATA_DIR}/config.json ] && cp ${VAULTWARDEN_DATA_DIR}/config.json ${BACKUP_DIR}/files/config.json

# JWT RSA Keys
[ -f ${VAULTWARDEN_DATA_DIR}/rsa_key.pem ] && cp ${VAULTWARDEN_DATA_DIR}/rsa_key.pem ${BACKUP_DIR}/files/rsa_key.pem
[ -f ${VAULTWARDEN_DATA_DIR}/rsa_key.pub.pem ] && cp ${VAULTWARDEN_DATA_DIR}/rsa_key.pub.pem ${BACKUP_DIR}/files/rsa_key.pub.pem

# Archive backup
tar -C ${BACKUP_DIR}/files -czvf ${BACKUP_DIR}/backup.tar.gz  ./

# Upload backup to oracle cloud
export OCI_CLI_AUTH=instance_principal
oci os object put --force --bucket-name ${BUCKET_NAME} --file ${BACKUP_DIR}/backup.tar.gz

# Delete backup directory
rm -rf ${BACKUP_DIR}

set +x
