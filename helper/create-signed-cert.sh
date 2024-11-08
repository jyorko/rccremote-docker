#!/bin/bash

# This script is only for demonstration purposes of how to create the server certificate.

# veirfy that parent folder is helper
if [ ! -d "../helper" ]; then
    echo "Please run this script from the helper folder."
    exit 1
fi

CERT_DIR=../certs
OPENSSL_CONF=./openssl.cnf
SERVER_NAME=rccremote.local

mkdir -p $CERT_DIR

# remove all crt/key/pem/csr files in the CERT_DIR after prompting the user
read -p "This will empty the cert dir $CERT_DIR. Are you sure? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f $CERT_DIR/*.{crt,key,pem,csr}
fi

echo ""

# 1. create a root CA certificate & key
echo "1. Creating a root CA certificate & key..."
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
    -keyout $CERT_DIR/rootCA.key \
    -out $CERT_DIR/rootCA.crt \
    -subj "/C=US/ST=State/L=City/O=YourOrg/OU=YourUnit/CN=RootCA"

# 2. Create a certificate bundle from the root certificate
echo "2. Creating a certificate bundle from the root certificate..."
openssl x509 -in $CERT_DIR/rootCA.crt -out $CERT_DIR/rootCA.pem -outform PEM

# 3. Generate the Server’s Private Key and Certificate Signing Request (CSR)
echo "3. Generating the Server’s Private Key and Certificate Signing Request (CSR)..."
openssl req -new -nodes -newkey rsa:2048 \
    -keyout $CERT_DIR/server.key \
    -out $CERT_DIR/server.csr \
    -config $OPENSSL_CONF \
    -subj "/C=US/ST=State/L=City/O=YourOrg/OU=YourUnit/CN=$SERVER_NAME"

# 4. Sign the Server Certificate with the Root Certificate
echo "4. Signing the Server Certificate with the Root Certificate..."
openssl x509 -req -days 3650 -in $CERT_DIR/server.csr \
    -CA $CERT_DIR/rootCA.crt -CAkey $CERT_DIR/rootCA.key -CAcreateserial \
    -out $CERT_DIR/server.crt -extensions v3_req -extfile $OPENSSL_CONF
