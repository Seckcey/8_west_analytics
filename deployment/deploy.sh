#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/opt/8west-analytics}"
COMPOSE_FILE="$APP_DIR/compose.yaml"
CONFIG_DIR="/etc/8west-analytics"

require_file() {
  [[ -f "$1" ]] || { echo "ERROR: missing $1" >&2; exit 1; }
}

command -v docker >/dev/null 2>&1 || { echo "ERROR: Docker is not installed." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: Docker daemon is unavailable to this user." >&2; exit 1; }
require_file "$COMPOSE_FILE"
require_file "$CONFIG_DIR/postgres.env"
require_file "$CONFIG_DIR/umami.env"

for file in "$CONFIG_DIR/postgres.env" "$CONFIG_DIR/umami.env"; do
  mode="$(stat -c '%a' "$file")"
  owner="$(stat -c '%U:%G' "$file")"
  [[ "$mode" == "600" ]] || { echo "ERROR: $file must have mode 600, found $mode" >&2; exit 1; }
  [[ "$owner" == "root:root" ]] || { echo "ERROR: $file must be owned by root:root, found $owner" >&2; exit 1; }
done

cd "$APP_DIR"

echo "Validating Compose configuration..."
docker compose -f "$COMPOSE_FILE" config --quiet

echo "Pulling pinned images..."
docker compose -f "$COMPOSE_FILE" pull

echo "Starting PostgreSQL and Umami..."
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

echo "Waiting for health checks..."
for attempt in $(seq 1 30); do
  postgres_health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 8west-analytics-postgres-1 2>/dev/null || true)"
  umami_health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 8west-analytics-umami-1 2>/dev/null || true)"
  if [[ "$postgres_health" == "healthy" && "$umami_health" == "healthy" ]]; then
    echo "Deployment healthy."
    docker compose -f "$COMPOSE_FILE" ps
    exit 0
  fi
  sleep 5
done

echo "ERROR: services did not become healthy." >&2
docker compose -f "$COMPOSE_FILE" ps >&2
docker compose -f "$COMPOSE_FILE" logs --tail=100 >&2
exit 1
