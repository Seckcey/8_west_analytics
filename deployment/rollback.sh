#!/usr/bin/env bash
set -Eeuo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "ERROR: run as root." >&2; exit 1; }

APP_DIR="${APP_DIR:-/opt/8west-analytics}"
COMPOSE_FILE="$APP_DIR/compose.yaml"

cd "$APP_DIR"

echo "Stopping application containers without deleting the PostgreSQL volume..."
docker compose -f "$COMPOSE_FILE" down --remove-orphans

echo "Safe rollback stopping point reached."
echo "No volume was deleted and no database restore was attempted."
echo "To roll back versions, update compose.yaml to approved image versions, restore a verified pre-upgrade backup if schema compatibility requires it, then run deployment/deploy.sh."
