#!/bin/bash

CERTBOT_DOMAIN=${CERTBOT_DOMAIN%%.duckdns.org}
CERTBOT_DOMAIN=${CERTBOT_DOMAIN##*.}

RESULT=$(curl -s "https://www.duckdns.org/update?domains=$CERTBOT_DOMAIN&token=$DUCK_DNS_TOKEN&txt=$CERTBOT_VALIDATION")

if [ "${RESULT}" != "OK" ]; then
  echo "Error trying to set txt record during DNS-01 challenge" >&2
  exit 1
fi

sleep 5

