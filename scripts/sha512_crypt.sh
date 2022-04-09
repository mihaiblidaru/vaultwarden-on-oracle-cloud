#!/bin/bash

script_input=$(cat)

salt=$(echo "${script_input}" | jq -r '.salt')
password=$(echo "${script_input}" | jq -r '.password')
hash=$(openssl passwd -6 -salt "${salt}" "${password}")

echo "{\"hash\": \"${hash}\"}"
