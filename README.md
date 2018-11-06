# Setup Private Docker Registry

## Features

1. AWS S3 bucket for Registry Data
2. Uses Letsencrypt certs

Make sure you have a domain name and SSH access to an instance. This works well on Ubuntu servers with Docker and Docker Compose installed.

## Steps

1. Clone repo.
2. Create `.env` based on `.env.example` and set your vars.
3. Get letsecrypt certs `docker-compose -f docker-compose.letsencrypt.yml up -d`
4. Generate auth date `./set_registry_auth.sh`
5. Start registry with `docker-compose -d docker-compose.registry.yml up -d`
6. You can renew 

## After it succeeds

1. `docker login registry.example.com -u username` and enter your password.
2. It should say `Login Succeeded`
3. You can use it.
