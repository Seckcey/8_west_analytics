#!/usr/bin/env bash
set -Eeuo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "ERROR: run as root." >&2; exit 1; }

APP_DIR="${APP_DIR:-/opt/8west-analytics}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/8west-analytics}"
COMPOSE_FILE="$APP_DIR/compose.yaml"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FINAL="$BACKUP_DIR/umami-$TIMESTAMP.dump"
TEMP="$FINAL.partial"
CHECKSUM="$FINAL.sha256"

cleanup() {
  rm -f "$TEMP"
}
trap cleanup EXIT

install -d -m 0700 -o root -g root "$BACKUP_DIR"
[[ -f "$COMPOSE_FILE" ]] || { echo "ERROR: missing $COMPOSE_FILE" >&2; exit 1; }

cd "$APP_DIR"
docker compose -f "$COMPOSE_FILE" ps --status running postgres | grep -q postgres || {
  echo "ERROR: PostgreSQL container is not running." >&2
  exit 1
}

start_epoch="$(date +%s)"
echo "Creating PostgreSQL backup: $(basename "$FINAL")"

umask 077
docker compose -f "$COMPOSE_FILE" exec -T postgres sh -lc \
  'exec pg_dump --format=custom --compress=6 --no-owner --no-acl --username="$POSTGRES_USER" --dbname="$POSTGRES_DB"' \
  > "$TEMP"

[[ -s "$TEMP" ]] || { echo "ERROR: backup is empty." >&2; exit 1; }

# Validate with pg_restore from the same PostgreSQL 17 container that created
# the archive. This prevents host client-version drift from rejecting a valid
# newer custom-format dump.
docker compose -f "$COMPOSE_FILE" exec -T postgres pg_restore --list < "$TEMP" >/dev/null

mv "$TEMP" "$FINAL"
sha256sum "$FINAL" > "$CHECKSUM"
chmod 0600 "$FINAL" "$CHECKSUM"
chown root:root "$FINAL" "$CHECKSUM"

end_epoch="$(date +%s)"
size_bytes="$(stat -c '%s' "$FINAL")"

echo "PASS: backup created and structurally validated"
echo "file=$FINAL"
echo "size_bytes=$size_bytes"
echo "duration_seconds=$((end_epoch - start_epoch))"
