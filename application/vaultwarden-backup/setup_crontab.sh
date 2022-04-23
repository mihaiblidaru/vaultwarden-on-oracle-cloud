#!/bin/bash
trap ctrl_c INT
trap _term SIGTERM

function _term() {
    echo "** Trapped SIGTERM. Exiting gracefully"
    exit 0
}

function ctrl_c() {
    echo "** Trapped CTRL-C. Exiting"
    exit 1
}


if [ "${DATABASE_URL}" == "" ]; then
  echo "Missing or empty 'DATABASE_URL' environment variable" >&2
  exit 1
fi

if [ "${BACKUP_BUCKET_NAME}" == "" ]; then
  echo "Missing or empty 'BACKUP_BUCKET_NAME' environment variable" >&2
  exit 1
fi

if [ "${BACKUPS_PASSWORD_SECRET_ID}" == "" ]; then
  echo "Missing or empty 'BACKUPS_PASSWORD_SECRET_ID' environment variable" >&2
  exit 1
fi

cat <<EOF > crontab_file
SHELL=/bin/bash
${CRON_EXPRESION:-0 3 * * *} bash /vaultwarden_backup.sh ${DATABASE_URL} ${BACKUP_BUCKET_NAME} ${BACKUPS_PASSWORD_SECRET_ID}
EOF

# Install crontabfile
crontab crontab_file

# Start crond
crond -f -l2 -L /dev/stderr &

wait
