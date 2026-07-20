#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR="/etc/8west-analytics"
POSTGRES_ENV="$CONFIG_DIR/postgres.env"
UMAMI_ENV="$CONFIG_DIR/umami.env"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo." >&2
  exit 1
fi

if [[ -e "$POSTGRES_ENV" || -e "$UMAMI_ENV" ]]; then
  echo "ERROR: environment files already exist; refusing to overwrite secrets." >&2
  exit 1
fi

install -d -m 0750 -o root -g root "$CONFIG_DIR"

POSTGRES_PASSWORD="$(openssl rand -base64 48 | tr -d '\n' | tr '/+' '_-')"
APP_SECRET="$(openssl rand -hex 48)"

umask 077
cat >"$POSTGRES_ENV" <<EOF
POSTGRES_DB=umami
POSTGRES_USER=umami
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
TZ=UTC
PGTZ=UTC
EOF

cat >"$UMAMI_ENV" <<EOF
DATABASE_URL=postgresql://umami:$POSTGRES_PASSWORD@postgres:5432/umami
APP_SECRET=$APP_SECRET
DISABLE_TELEMETRY=1
TZ=UTC
EOF

chown root:root "$POSTGRES_ENV" "$UMAMI_ENV"
chmod 0600 "$POSTGRES_ENV" "$UMAMI_ENV"

unset POSTGRES_PASSWORD APP_SECRET

echo "Created protected runtime environment files:"
echo "  $POSTGRES_ENV"
echo "  $UMAMI_ENV"
echo "Secret values were not printed."
