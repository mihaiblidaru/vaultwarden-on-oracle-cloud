#!/bin/bash

ROOT_COMPARTMENT_ID=$(grep ^root_compartment_id config.yml | cut -d ":" -f2 | xargs)
REGION=$(grep ^region config.yml | cut -d ":" -f2 | xargs)
CREATE_BUCKET_RESPONSE=$(oci os bucket create --name terraform-states --compartment-id ${ROOT_COMPARTMENT_ID} 2>&1 )
if [ "$?" != "0" ]; then
    BUCKET_ALREADY_EXISTS=$(echo "${CREATE_BUCKET_RESPONSE}" | grep -o BucketAlreadyExists)
    if [ "$BUCKET_ALREADY_EXISTS" != "BucketAlreadyExists" ]; then
        echo "Error while creating terraform-states bucket"
        echo "${CREATE_BUCKET_RESPONSE}"
        exit
    else
        echo "Bucket already exists. Continuing"
    fi
fi

ACCESS_URI=$(oci os preauth-request create --bucket-name terraform-states --access-type ObjectReadWrite  --name "terraform-preauth-request" --object-name "tfstate" --time-expires $(date -d "+1 year" "+%Y-%m-%d") | jq -r '.data."access-uri"')

# Check if access uri has the right format
(echo ${ACCESS_URI} | grep '^/p/') || (echo "Could not create preauthenticated request"; exit 1)

cat << EOF > backend.tf

terraform {
  backend "http" {
    address = "https://objectstorage.${REGION}.oraclecloud.com${ACCESS_URI}"
    update_method = "PUT"
  }
}
EOF
