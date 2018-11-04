#!/bin/bash

source .env

docker run -it --rm \
    -v $PWD/certs:/etc/letsencrypt \
    -v $PWD/certs-data:/data/letsencrypt \
    certbot/certbot \
    certonly \
    --webroot --webroot-path=/data/letsencrypt \
    -d $DOMAIN
