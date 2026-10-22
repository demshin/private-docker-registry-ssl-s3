# CLAUDE.md

## What this is

A showcase (not production) single-host Docker Registry v3 (`registry:3.x`) storing images in S3, behind Caddy, which gets and renews the Let's Encrypt certificate. Goal: minimal, readable, working. No build or lint; the only test is the local end-to-end run below. Main branch is `master`.

Setup and the variable list live in README.md; the steps are `cp .env.example .env`, `./set_registry_auth.sh <user>`, `docker compose up -d`.

## How the pieces connect

- `config.yml` holds static registry settings. S3 values reach the registry as `REGISTRY_STORAGE_S3_*` env set in `compose.yaml` from `.env`; `storage: s3: {}` in `config.yml` is the placeholder they fill (the docs advise a base file plus env overrides of single values, not whole sections).
- `http.host` is deliberately unset: the registry builds `Location` headers from Caddy's `X-Forwarded-*`, which is what lets one config serve both the real domain and `localhost:8443` in the test.
- With a custom `S3_ENDPOINT`, registry v3 requires `S3_FORCEPATHSTYLE=true`. An empty endpoint is treated as AWS.
- S3 presigned redirects stay on in the main setup (clients pull layers straight from the bucket). The test disables them because the Docker daemon cannot resolve `rustfs:9000`.
- `auth/htpasswd` must exist before `up`: registry v3 provisions a default user with a generated password when the file is missing. Only bcrypt entries are accepted.
- Image tags are pinned exactly (`registry:3.1.2`, `caddy:2.11.7`, `httpd:2.4.69` for htpasswd only, `rustfs/rustfs:1.0.3` in the test).

## Local test

```sh
printf 'testpass\n' | ./set_registry_auth.sh testuser test-auth/htpasswd
docker compose -f compose.yaml -f compose.test.yaml --env-file .env.example up -d --wait
```

Then login/push/pull against `localhost:8443` (README has the full sequence) and list the bucket through `rustfs` with `curl --aws-sigv4`.

- The test is its own Compose project (`registry-test`) with its own `test-auth/`, so `down -v` never touches a real setup's Caddy volumes or users. Keep that isolation when editing `compose.test.yaml`.
- RustFS replaces MinIO because MinIO no longer publishes images (Docker Hub 404, quay 401).
- `ports: !override` needs Compose 2.24.4+.
- After `docker image rm`, `docker pull` often serves the layer from containerd's local content store. Prove the pull path with `GET /v2/.../blobs/... 200` in the registry log, or by fetching the blob via `curl -k -u testuser:testpass https://localhost:8443/v2/test/alpine/blobs/<digest>` and comparing its sha256.
- `Unavailable` lines during `docker push` are the client's pre-upload `HEAD` (401 challenge, then 404); check the registry log for 5xx instead.

## Environment gotchas

- The sandbox denies reading `.env` and `.env.*` (including `.env.example`), and hooks block commands that name them. Ask the user to edit `.env.example` and to run `git diff` on it.
- The Docker socket is outside the sandbox: `docker` commands need the sandbox disabled.
- `auth/`, `test-auth/` and `.env` are git-ignored; stage files by name.
