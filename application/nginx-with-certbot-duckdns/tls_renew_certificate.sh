#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Illegal number of parameters" >&2
    echo "Use: $0 <email> <duck_dns_domain> <duck_dns_token>" >&2
    exit 1
fi

EMAIL=$1
DOMAIN=$2
export DUCK_DNS_TOKEN=$3

certbot certonly                         \
  -v                                     \
  --manual                               \
  --test-cert                            \
  --preferred-challenges dns             \
  --non-interactive                      \
  --agree-tos                            \
  --manual-public-ip-logging-ok          \
  --manual-auth-hook /challenge-hook.sh  \
  --manual-cleanup-hook /cleanup-hook.sh \
  --email ${EMAIL}                       \
  --domain ${DOMAIN}                     \
