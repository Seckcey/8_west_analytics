#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/opt/8west-analytics}"
COMPOSE_FILE="$APP_DIR/compose.yaml"

cd "$APP_DIR"
docker compose -f "$COMPOSE_FILE" config --quiet

postgres_id="$(docker compose -f "$COMPOSE_FILE" ps -q postgres)"
umami_id="$(docker compose -f "$COMPOSE_FILE" ps -q umami)"

[[ -n "$postgres_id" ]] || { echo "FAIL: PostgreSQL container is missing." >&2; exit 1; }
[[ -n "$umami_id" ]] || { echo "FAIL: Umami container is missing." >&2; exit 1; }

postgres_health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$postgres_id")"
umami_health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$umami_id")"

[[ "$postgres_health" == "healthy" ]] || { echo "FAIL: PostgreSQL is $postgres_health." >&2; exit 1; }
[[ "$umami_health" == "healthy" ]] || { echo "FAIL: Umami is $umami_health." >&2; exit 1; }

curl -fsS http://127.0.0.1:3000/api/heartbeat >/dev/null

if ss -lnt | awk '{print $4}' | grep -Eq '(^|:)5432$'; then
  echo "FAIL: PostgreSQL port 5432 is listening on the host." >&2
  exit 1
fi

if ! ss -lnt | awk '{print $4}' | grep -q '127.0.0.1:3000'; then
  echo "FAIL: Umami is not bound to 127.0.0.1:3000." >&2
  exit 1
fi

echo "PASS: PostgreSQL is healthy and not published on the host."
echo "PASS: Umami is healthy and reachable only through loopback port 3000."
echo "PASS: Compose configuration is valid."
docker compose -f "$COMPOSE_FILE" ps
