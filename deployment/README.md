# Deployment

The pre-v1 platform is deployed and validated on the approved dedicated EC2 instance. Production website and application instrumentation remains gated on explicit approval from Frankie and Mary. These scripts operate the approved Docker stack; they do not create cloud resources, modify DNS, or alter other application repositories.

## Runtime layout

- host Caddy service terminates TLS and proxies to `127.0.0.1:3000`
- Umami runs in Docker and publishes only to loopback
- PostgreSQL runs in Docker on an internal network with no host port
- runtime secrets live under `/etc/8west-analytics`
- the repository is expected at `/opt/8west-analytics`

## Pinned images

- `docker.umami.is/umami-software/umami:3.1.0`
- `postgres:17.10-alpine3.23`

Image upgrades require a backup, release review, explicit approval, and rollback plan.

## Scripts

All deployment and shutdown scripts must run as root because Docker Compose must read root-owned mode `0600` runtime environment files.

### `generate-secrets.sh`

Creates `/etc/8west-analytics/postgres.env` and `/etc/8west-analytics/umami.env` as root-owned mode `0600` files. It refuses to overwrite existing secrets and does not print generated values.

Run once:

```bash
sudo ./deployment/generate-secrets.sh
```

### `deploy.sh`

Validates Docker access, secret ownership and permissions, Compose syntax, image pulls, service startup, and container health.

```bash
sudo ./deployment/deploy.sh
```

### `verify.sh`

Confirms both containers are healthy, PostgreSQL is not published on the host, Umami is bound only to loopback, and the heartbeat endpoint responds.

```bash
sudo ./deployment/verify.sh
```

### `rollback.sh`

Stops the containers and preserves the PostgreSQL volume. It does not pretend to change image versions or reverse database migrations. Version rollback requires an approved `compose.yaml` change and a verified pre-upgrade database restore when schema compatibility requires it.

```bash
sudo ./deployment/rollback.sh
```

### `uninstall.sh`

Stops and removes containers and networks while preserving the database volume, secrets, backups, Caddy configuration, repository, and DNS. Destructive volume deletion is intentionally not automated.

```bash
sudo ./deployment/uninstall.sh
```

## Checkout preparation

GitHub's contents API does not preserve executable bits for newly created files. After pulling the branch onto Linux, run:

```bash
chmod 0755 deployment/*.sh operations/*.sh
```

## First-login gate

Umami creates a known initial administrator account. Change the default password immediately after the first successful login and before adding any production property.

## Privacy gate

Umami v3.1.0 includes Session Replay. Session replay, heatmaps, form capture, and keystroke capture are prohibited for this project and must not be enabled or instrumented.
