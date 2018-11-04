#!/bin/bash

source .env

mkdir -p data/auth

docker run \
  --entrypoint htpasswd \
  registry:2 -Bbn $USER $PASSWORD > data/auth/htpasswd
