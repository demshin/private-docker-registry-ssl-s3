# Private Docker Registry on S3 with automatic TLS

A single-host [Docker Registry](https://github.com/distribution/distribution) v3 that keeps images in S3
(AWS or any S3-compatible storage), behind [Caddy](https://caddyserver.com), which obtains and renews
a Let's Encrypt certificate on its own.

## Why

This repo started in 2018 as a workaround for [distribution#2545](https://github.com/distribution/distribution/issues/2545):
Let's Encrypt disabled the TLS-SNI-01 challenge, and the registry's built-in ACME client had no other
challenge it could answer on its single port. The workaround was a one-shot certbot container and manual renewals.

The issue is fixed in distribution v3: the built-in client was replaced with `golang.org/x/crypto/acme/autocert`,
which uses TLS-ALPN-01 on port 443 ([#2926](https://github.com/distribution/distribution/pull/2926)).
The fix was never backported to v2, so `registry:2` still cannot get a certificate by itself.

This example still puts Caddy in front: it redirects HTTP to HTTPS, falls back between HTTP-01 and
TLS-ALPN-01 challenges, keeps TLS out of the registry config, and can serve other sites on the same host.
If you prefer one container fewer, `http.tls.letsencrypt` in the registry config works on v3.

## Requirements

- Linux host with Docker Engine and Docker Compose v2
- A domain whose DNS record points to the host, with ports 80 and 443 reachable from the internet
- An existing S3 bucket, plus access keys or an IAM instance role with the
  [permissions the S3 driver needs](https://distribution.github.io/distribution/storage-drivers/s3/#s3-permission-scopes)

## Quick start

1. `cp .env.example .env` and fill it in.
2. `./set_registry_auth.sh alice` — prompts for a password and writes a bcrypt entry to `auth/htpasswd`.
3. `docker compose up -d`
4. `docker login registry.example.com -u alice`

To add a user or change a password, rerun step 2, then `docker compose restart registry`.

## Configuration

All variables live in `.env`:

| Variable | Required | Description |
|---|---|---|
| `DOMAIN` | yes | Public domain of the registry; Caddy requests the certificate for it |
| `ACME_EMAIL` | yes | Email for the Let's Encrypt account |
| `S3_REGION` | yes | Bucket region, e.g. `us-east-1` |
| `S3_BUCKET` | yes | Bucket name; the bucket must already exist |
| `S3_ACCESSKEY`, `S3_SECRETKEY` | no | Static credentials; leave empty to use an IAM instance role |
| `S3_ENDPOINT` | no | Endpoint of an S3-compatible storage (RustFS, SeaweedFS, MinIO, ...); empty for AWS |
| `S3_FORCEPATHSTYLE` | no | Path-style bucket addressing; must be `true` when `S3_ENDPOINT` is set |

Static registry settings are in `config.yml`; Caddy's in `Caddyfile`.

By default the registry answers pulls with a redirect to a presigned S3 URL, so Docker clients
download layers straight from the bucket. If clients cannot reach `S3_ENDPOINT` (a private storage network),
add `redirect: {disable: true}` under `storage` in `config.yml` to stream layers through the registry.

## Testing locally with RustFS

MinIO no longer publishes container images, so the local test uses [RustFS](https://github.com/rustfs/rustfs)
as the S3 backend. `compose.test.yaml` adds RustFS and a bucket, points the registry at it, and serves
Caddy on `https://localhost:8443` with its internal CA (Docker skips certificate checks for `localhost`).
The test runs as a separate Compose project with its own `test-auth/`, so it does not touch a real setup
in the same checkout. It needs Docker Compose 2.24.4 or newer (`ports: !override`).

```sh
printf 'testpass\n' | ./set_registry_auth.sh testuser test-auth/htpasswd
docker compose -f compose.yaml -f compose.test.yaml --env-file .env.example up -d --wait

echo testpass | docker login localhost:8443 -u testuser --password-stdin
docker pull alpine:3.22
docker tag alpine:3.22 localhost:8443/test/alpine:3.22
docker push localhost:8443/test/alpine:3.22
docker pull localhost:8443/test/alpine:3.22

# Objects the registry wrote to the bucket
docker compose -f compose.yaml -f compose.test.yaml --env-file .env.example exec rustfs \
  curl -s --aws-sigv4 aws:amz:us-east-1:s3 -u testaccesskey:testsecretkey 'http://localhost:9000/registry?list-type=2'

docker compose -f compose.yaml -f compose.test.yaml --env-file .env.example down -v
```
