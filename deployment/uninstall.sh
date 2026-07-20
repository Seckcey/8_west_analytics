#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/opt/8west-analytics}"
COMPOSE_FILE="$APP_DIR/compose.yaml"

cd "$APP_DIR"

if [[ "${1:-}" == "--destroy-data" ]]; then
  echo "ERROR: destructive volume removal is intentionally not automated." >&2
  echo "Create and verify a final backup, then remove the named volume manually with explicit approval." >&2
  exit 1
fi

echo "Stopping and removing application containers and networks."
echo "The PostgreSQL volume, secrets, repository, backups, Caddy configuration, and DNS are preserved."
docker compose -f "$COMPOSE_FILE" down --remove-orphans

echo "Safe uninstall stage complete. No persistent data was deleted."
