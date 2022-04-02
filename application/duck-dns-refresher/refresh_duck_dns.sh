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

if [ "${DUCK_DNS_DOMAIN_PREFIX}" == "" ]; then
    echo "Missing or empty environment variable DUCK_DNS_DOMAIN_PREFIX"
    exit 1
fi

if [ "${DUCK_DNS_TOKEN}" == "" ]; then
    echo "Missing or empty environment variable DUCK_DNS_TOKEN"
    exit 1
fi

while true
do
    response=$(curl -sS "https://www.duckdns.org/update?domains=${DUCK_DNS_DOMAIN_PREFIX}&token=${DUCK_DNS_TOKEN}&ip=")
    echo "DuckDns response: $response"
    echo $response > last_response
    sleep ${REFRESH_INTERVAL:-300} &
    wait
done

