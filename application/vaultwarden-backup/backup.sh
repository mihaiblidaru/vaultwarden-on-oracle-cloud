#!/bin/bash
set -x

URL=$1
BUCKET_NAME=$2

BACKUP_DIR=$(mktemp -d /tmp/backup.XXXXXX)
mkdir -p ${BACKUP_DIR}/files
pg_dump ${URL} -f ${BACKUP_DIR}/files/db.sql

tar -C ${BACKUP_DIR}/files -czvf ${BACKUP_DIR}/backup.tar.gz  ./

export OCI_CLI_AUTH=instance_principal

oci os object put --force --bucket-name ${BUCKET_NAME} --file ${BACKUP_DIR}/backup.tar.gz

rm -rf ${BACKUP_DIR}

set +x
