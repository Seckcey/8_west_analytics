# Deployment

Deployment remains gated on explicit approval from Frankie and Mary. These scripts prepare and operate the approved Docker stack; they do not create cloud resources, modify DNS, or alter other application repositories.

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

### `generate-secrets.sh`

Creates `/etc/8west-analytics/postgres.env` and `/etc/8west-analytics/umami.env` as root-owned mode `0600` files. It refuses to overwrite existing secrets and does not print generated values.

Run once:

```bash
sudo ./deployment/generate-secrets.sh
```

### `deploy.sh`

Validates Docker access, secret ownership and permissions, Compose syntax, image pulls, service startup, and container health.

```bash
./deployment/deploy.sh
```

### `verify.sh`

Confirms both containers are healthy, PostgreSQL is not published on the host, Umami is bound only to loopback, and the heartbeat endpoint responds.

```bash
./deployment/verify.sh
```

### `rollback.sh`

Performs only a safe stop and preserves the PostgreSQL volume. Database schema rollback is never automatic. Restore from a verified pre-upgrade backup when schema compatibility requires it.

### `uninstall.sh`

Stops and removes containers and networks while preserving the database volume, secrets, backups, Caddy configuration, repository, and DNS. Destructive volume deletion is intentionally not automated.

## Checkout preparation

GitHub's contents API does not preserve executable bits for newly created files. After pulling the branch onto Linux, run:

```bash
chmod 0755 deployment/*.sh
```

## First-login gate

Umami creates a known initial administrator account. Change the default password immediately after the first successful login and before adding any production property.

## Privacy gate

Umami v3.1.0 includes Session Replay. Session replay, heatmaps, form capture, and keystroke capture are prohibited for this project and must not be enabled or instrumented.
