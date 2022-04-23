#!/bin/bash
set -x

PG_URL=$1
BUCKET_NAME=$2
BACKUPS_PASSWORD_SECRET_ID=$3


# Create tmp directories for backups
BACKUP_DIR=$(mktemp -d /tmp/backup.XXXXXX)
mkdir -p ${BACKUP_DIR}/files

# Dump postgres database
pg_dump ${PG_URL} -f ${BACKUP_DIR}/files/db.sql

# Attachments
[ -d /vaultwarden-data/attachments/ ] && cp -r /vaultwarden-data/attachments/ ${BACKUP_DIR}/files/attachments/

# Sends
[ -d /vaultwarden-data/sends/ ] && cp -r /vaultwarden-data/sends/ ${BACKUP_DIR}/files/sends/

# Config
[ -f /vaultwarden-data/config.json ] && cp /vaultwarden-data/config.json ${BACKUP_DIR}/files/config.json

# JWT RSA Keys
[ -f /vaultwarden-data/rsa_key.pem ] && cp /vaultwarden-data/rsa_key.pem ${BACKUP_DIR}/files/rsa_key.pem
[ -f /vaultwarden-data/rsa_key.pub.pem ] && cp /vaultwarden-data/rsa_key.pub.pem ${BACKUP_DIR}/files/rsa_key.pub.pem

# Let's encrypt certbot configuration, keys and certificates
[ -d /letsencrypt/ ] && cp -r /letsencrypt/ ${BACKUP_DIR}/files/letsencrypt/

# Archive backup
tar -C ${BACKUP_DIR}/files -czvf ${BACKUP_DIR}/backup.tar.gz  ./

export OCI_CLI_AUTH=instance_principal

PASSWORD_TMP_FILE=$(mktemp)

# Get backups password
BACKUPS_PASSWORD_HASH_SECRET_ID=$(curl -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/backups_password_secret_id)
oci secrets secret-bundle get --secret-id ${BACKUPS_PASSWORD_HASH_SECRET_ID} --query 'data."secret-bundle-content".content' --raw-output | base64 -d > ${PASSWORD_TMP_FILE}

# Encrypt backup
openssl enc -aes-256-cbc -pbkdf2 -in ${BACKUP_DIR}/backup.tar.gz -out ${BACKUP_DIR}/backup.tar.gz.enc -pass "file:${PASSWORD_TMP_FILE}"

# Upload backup to oracle cloud
oci os object put --force --bucket-name ${BUCKET_NAME} --file ${BACKUP_DIR}/backup.tar.gz.enc

# Delete backup directory
rm -rf ${BACKUP_DIR}

# Delete password file
rm -f ${PASSWORD_TMP_FILE}

set +x
