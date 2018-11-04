# Setup Private Docker Registry

## Features

1. AWS S3 bucket for Registry Data
2. Uses Letsencrypt certs
3. Tested on AWS S3

Make sure you have a domain name and SSH access to an instance. This works well on Ubuntu servers with Docker and Docker Compose installed.

## Steps

1. Create `.env` based on `.env.example` and set your vars.
2. `docker-compose up -d`
3. `chmod +x *.sh && ./ssl_gen.sh`  
4. After it succeeds, start it with `docker-compose restart`

## After it succeeds

1. From your local machine (or another) add your repo url to the `insecure-registries` (instructions: https://docs.docker.com/registry/insecure/)
2. `docker login my-repo-url.com` give your user name/pass
3. It should say `Login Succeeded`

## Automatic cron setup

This will schedule a renewal of the SSL cert with Let's Encrypt every 15 days.

1. `crontab -u $USER -e`
2. `0 0 */15 * *  /path/to/registry_files/ssl_renew.sh`
