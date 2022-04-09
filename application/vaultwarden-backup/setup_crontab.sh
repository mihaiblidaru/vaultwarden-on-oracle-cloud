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

cat <<EOF > crontab_file
SHELL=/bin/bash
${CRON_EXPRESION:-0 3 * * *} bash /backup.sh ${DATABASE_URL} ${BACKUP_BUCKET_NAME}
EOF

# Install crontabfile
crontab crontab_file

# Start crond
crond -f -l2 -L /dev/stderr &

wait
