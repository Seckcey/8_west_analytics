#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/opt/8west-analytics}"
COMPOSE_FILE="$APP_DIR/compose.yaml"

cd "$APP_DIR"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <umami-image> <postgres-image>" >&2
  echo "Example: $0 docker.umami.is/umami-software/umami:3.1.0 postgres:17.10-alpine3.23" >&2
  exit 2
fi

UMAMI_IMAGE="$1"
POSTGRES_IMAGE="$2"

export UMAMI_IMAGE POSTGRES_IMAGE

echo "Stopping application containers without deleting the database volume..."
docker compose -f "$COMPOSE_FILE" down

echo "Rollback requires compose.yaml to reference the requested approved versions."
echo "Requested Umami image: $UMAMI_IMAGE"
echo "Requested PostgreSQL image: $POSTGRES_IMAGE"
echo "No volume was deleted and no database restore was attempted."
echo "Update the approved compose file, then run deployment/deploy.sh."
