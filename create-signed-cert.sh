#!/bin/bash

mkdir -p certs

# create a root CA certificate & key

openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
    -keyout certs/rootCA.key \
    -out certs/rootCA.crt \
    -subj "/C=US/ST=State/L=City/O=YourOrg/OU=YourUnit/CN=RootCA"

# Create a certificate bundle from the root certificate

openssl x509 -in certs/rootCA.crt -out certs/rootCA.pem -outform PEM

# Generate the Server’s Private Key and Certificate Signing Request (CSR)
openssl req -new -nodes -newkey rsa:2048 \
    -keyout certs/server.key \
    -out certs/server.csr \
    -config openssl.cnf \
    -subj "/C=US/ST=State/L=City/O=YourOrg/OU=YourUnit/CN=rccremote"

# Sign the Server Certificate with the Root Certificate
openssl x509 -req -days 3650 -in certs/server.csr \
    -CA certs/rootCA.crt -CAkey certs/rootCA.key -CAcreateserial \
    -out certs/server.crt -extensions v3_req -extfile openssl.cnf

# delete any line after "ca-bundle"
sed -i '/ca-bundle/,$d' rcc-profile-cabundle.yaml

echo "ca-bundle: |" >>rcc-profile-cabundle.yaml

# Add the PEM file content to the profile YAML file
cat certs/rootCA.pem >>rcc-profile-cabundle.yaml

# indent any line after "ca-bundle" with two spaces
sed -i '/ca-bundle/!b;n;:a;s/^/  /;n;ba' rcc-profile-cabundle.yaml
