#!/bin/bash
trap ctrl_c INT
trap _term SIGTERM
set -x
function _term() {
  echo "** Trapped SIGTERM. Exiting gracefully"
  exit 0
}

function ctrl_c() {
  echo "** Trapped CTRL-C. Exiting"
  exit 1
}

if [ "${EMAIL}" == "" ]; then
  echo "Missing or empty 'EMAIL' environment variable" >&2
  exit 1
fi

if [ "${DOMAIN}" == "" ]; then
  echo "Missing or empty 'DOMAIN' environment variable" >&2
  exit 1
fi

if [ "${DUCK_DNS_TOKEN}" == "" ]; then
  echo "Missing or empty 'DUCK_DNS_TOKEN' environment variable" >&2
  exit 1
fi

curl -sS "https://www.duckdns.org/update?domains=${DOMAIN}&token=${DUCK_DNS_TOKEN}&ip="

# Get or renew certificate before starting nginx
./tls_renew_certificate.sh ${EMAIL} ${DOMAIN} ${DUCK_DNS_TOKEN}

# Setup certificate renewal
echo "\
SHELL=/bin/bash
${CRON_EXPRESION:-0 5 * * *} bash /tls_renew_certificate.sh ${EMAIL} ${DOMAIN} ${DUCK_DNS_TOKEN} \
" | crontab -

# Start crond
crond -f -l2 -L /dev/stderr &

< /nginx-template.conf envsubst '${EMAIL} ${DOMAIN} ${DUCK_DNS_TOKEN}'  > /etc/nginx/nginx.conf

nginx -g "daemon off;" &

wait
