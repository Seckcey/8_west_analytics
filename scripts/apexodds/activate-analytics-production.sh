#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_PUBLIC_IP="35.172.195.208"
EXPECTED_DOMAIN="apexodds.8westventures.com"
EXPECTED_CURRENT_HEAD="3b538874947a617f3ea94008fab3ed8f5e9d2083"
EXPECTED_TARGET_SHA="2fad7675cb8d07f0590dc1edb432f471913f5680"
EXPECTED_CURRENT_IMAGE_ID="sha256:6f65689993c367284887ffa3bba99e2dbc209dda4547a119dcf428c01172afb3"
EXPECTED_PROPERTY_ID="d1f9c3cd-1115-4037-a679-cea8bf9bd09c"
APP_DIR="/home/ubuntu/apexodds"
BACKUP_ROOT="/var/backups/8west-analytics-integrations"
COMPOSE_ARGS=(-f docker-compose.yml -f docker-compose.https.yml)
CANDIDATE_PORT="18787"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${BACKUP_ROOT}/apexodds-${STAMP}"
ROLLBACK_IMAGE="apexodds:rollback-${STAMP}"
CANDIDATE_IMAGE="apexodds:candidate-${STAMP}"
CANDIDATE_CONTAINER="apexodds-analytics-candidate-${STAMP,,}"
CANDIDATE_STATE_DIR="${BACKUP_DIR}/candidate-state"

OLD_HEAD=""
SOURCE_MOVED=0
SNAPSHOT_STOPPED=0
ACTIVATED=0
CANDIDATE_STARTED=0
ENV_HASH_BEFORE=""
SECRETS_HASH_BEFORE=""

section() {
  printf '\n===== %s =====\n' "$1"
}

wait_local_health() {
  local url="$1"
  local attempts="${2:-60}"
  local i
  for ((i = 1; i <= attempts; i++)); do
    if curl -fsS --connect-timeout 2 --max-time 5 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

cleanup_candidate() {
  set +e
  if [[ "$CANDIDATE_STARTED" == "1" ]]; then
    docker rm -f "$CANDIDATE_CONTAINER" >/dev/null 2>&1 || true
    CANDIDATE_STARTED=0
  fi
  set -e
}

restore_snapshot_services() {
  set +e
  if [[ "$SNAPSHOT_STOPPED" == "1" ]]; then
    docker start apexodds-ui apexodds-paper-learn >/dev/null 2>&1 || true
    SNAPSHOT_STOPPED=0
  fi
  set -e
}

rollback() {
  local reason="$1"
  trap - ERR
  set +e

  printf '\nROLLBACK STARTED: %s\n' "$reason"
  cleanup_candidate

  cd "$APP_DIR" || true
  docker stop apexodds-paper-learn apexodds-ui >/dev/null 2>&1 || true

  if [[ -f "${BACKUP_DIR}/persistent-state.tgz" ]]; then
    rm -rf data secrets
    rm -f .env
    tar -xzf "${BACKUP_DIR}/persistent-state.tgz" -C "$APP_DIR" || true
  fi

  if [[ -n "$OLD_HEAD" ]]; then
    git reset --hard "$OLD_HEAD" >/dev/null 2>&1 || true
  fi

  docker image tag "$ROLLBACK_IMAGE" apexodds:latest >/dev/null 2>&1 || true
  docker compose "${COMPOSE_ARGS[@]}" up -d --no-build --force-recreate \
    apexodds-ui apexodds-paper-learn >/dev/null 2>&1 || true

  if wait_local_health "http://127.0.0.1:8787/api/health" 60; then
    printf 'rollback_local_health=PASS\n'
  else
    printf 'rollback_local_health=FAIL\n'
  fi

  if curl -fsS --connect-timeout 5 --max-time 20 \
    "https://${EXPECTED_DOMAIN}/api/health" >/dev/null 2>&1; then
    printf 'rollback_public_health=PASS\n'
  else
    printf 'rollback_public_health=FAIL\n'
  fi

  printf 'rollback_head=%s\n' "$(git rev-parse HEAD 2>/dev/null || true)"
  printf 'backup=%s\n' "$BACKUP_DIR"
  printf 'production_changed=ROLLED_BACK\n'
  exit 1
}

stop() {
  local reason="$1"
  trap - ERR
  cleanup_candidate
  restore_snapshot_services

  if [[ "$SOURCE_MOVED" == "1" && "$ACTIVATED" == "0" && -n "$OLD_HEAD" ]]; then
    cd "$APP_DIR" || true
    git reset --hard "$OLD_HEAD" >/dev/null 2>&1 || true
    SOURCE_MOVED=0
  fi

  printf 'STOP: %s\n' "$reason" >&2
  printf 'production_changed=NO\n' >&2
  exit 1
}

on_error() {
  local line="$1"
  local command="$2"
  local status="$3"
  if [[ "$ACTIVATED" == "1" ]]; then
    rollback "command failed at line ${line}: ${command} (status ${status})"
  else
    stop "command failed at line ${line}: ${command} (status ${status})"
  fi
}

trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR

[[ "$EUID" -ne 0 ]] || stop "run this script as the ubuntu user, not root"

section "IDENTITY AND PRECONDITIONS"
PUBLIC_IP="$(curl -4 -fsS --connect-timeout 10 --max-time 20 \
  https://checkip.amazonaws.com | tr -d '[:space:]')"
printf 'public_ip=%s\n' "$PUBLIC_IP"
[[ "$PUBLIC_IP" == "$EXPECTED_PUBLIC_IP" ]] || \
  stop "wrong server: expected ${EXPECTED_PUBLIC_IP}"

[[ -d "$APP_DIR/.git" ]] || stop "Git checkout missing at ${APP_DIR}"
cd "$APP_DIR"

CURRENT_BRANCH="$(git branch --show-current)"
OLD_HEAD="$(git rev-parse HEAD)"
printf 'current_branch=%s\n' "$CURRENT_BRANCH"
printf 'current_head=%s\n' "$OLD_HEAD"
[[ "$CURRENT_BRANCH" == "main" ]] || stop "production checkout is not on main"
[[ "$OLD_HEAD" == "$EXPECTED_CURRENT_HEAD" ]] || \
  stop "production head changed since preflight"

[[ -z "$(git status --porcelain=v1)" ]] || stop "production checkout is not clean"

REMOTE_MAIN="$(git ls-remote --exit-code origin refs/heads/main | awk '{print $1}')"
printf 'remote_main=%s\n' "$REMOTE_MAIN"
[[ "$REMOTE_MAIN" == "$EXPECTED_TARGET_SHA" ]] || \
  stop "origin/main moved since approval"

CURRENT_IMAGE_ID="$(docker image inspect apexodds:latest --format '{{.Id}}')"
printf 'current_image_id=%s\n' "$CURRENT_IMAGE_ID"
[[ "$CURRENT_IMAGE_ID" == "$EXPECTED_CURRENT_IMAGE_ID" ]] || \
  stop "current production image changed since preflight"

for container in apexodds-ui apexodds-paper-learn apexodds-caddy; do
  [[ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)" == "true" ]] || \
    stop "container not running: ${container}"
done

[[ "$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
  apexodds-ui)" == "healthy" ]] || stop "apexodds-ui is not healthy"

curl -fsS --connect-timeout 5 --max-time 20 \
  http://127.0.0.1:8787/api/health >/dev/null || stop "local health failed"
curl -fsS --connect-timeout 5 --max-time 20 \
  "https://${EXPECTED_DOMAIN}/api/health" >/dev/null || stop "public health failed"

[[ -f .env ]] || stop ".env is missing"
[[ -d data ]] || stop "data directory is missing"
[[ -d secrets ]] || stop "secrets directory is missing"

AVAILABLE_KB="$(df --output=avail -k "$APP_DIR" | tail -1 | tr -d '[:space:]')"
printf 'available_kb=%s\n' "$AVAILABLE_KB"
(( AVAILABLE_KB >= 1000000 )) || stop "less than 1 GB free disk space"

if ss -ltn | awk '{print $4}' | grep -Eq "(:|\])${CANDIDATE_PORT}$"; then
  stop "candidate port ${CANDIDATE_PORT} is already in use"
fi

ENV_HASH_BEFORE="$(sha256sum .env | awk '{print $1}')"
SECRETS_HASH_BEFORE="$(
  find secrets -type f -print0 |
    sort -z |
    xargs -0 -r sha256sum |
    sha256sum |
    awk '{print $1}'
)"

printf 'PASS: exact approved production baseline verified\n'

section "LOCAL BACKUP"
sudo install -d -m 700 -o "$(id -un)" -g "$(id -gn)" "$BACKUP_ROOT"
install -d -m 700 "$BACKUP_DIR"

docker image tag apexodds:latest "$ROLLBACK_IMAGE"
printf 'rollback_image=%s\n' "$ROLLBACK_IMAGE"

git bundle create "${BACKUP_DIR}/source-before.bundle" HEAD
printf '%s\n' "$OLD_HEAD" > "${BACKUP_DIR}/SOURCE_BEFORE"

docker stop apexodds-paper-learn apexodds-ui >/dev/null
SNAPSHOT_STOPPED=1

tar -czf "${BACKUP_DIR}/persistent-state.tgz" .env data secrets
tar -tzf "${BACKUP_DIR}/persistent-state.tgz" >/dev/null

install -d -m 700 "$CANDIDATE_STATE_DIR"
tar -xzf "${BACKUP_DIR}/persistent-state.tgz" -C "$CANDIDATE_STATE_DIR"

docker start apexodds-ui apexodds-paper-learn >/dev/null
SNAPSHOT_STOPPED=0
wait_local_health "http://127.0.0.1:8787/api/health" 60 || \
  stop "old production did not recover after snapshot"
curl -fsS --connect-timeout 5 --max-time 20 \
  "https://${EXPECTED_DOMAIN}/api/health" >/dev/null || \
  stop "public production did not recover after snapshot"

printf 'backup=%s\n' "$BACKUP_DIR"
printf 'PASS: persistent state snapshot and source bundle created\n'

section "FETCH APPROVED SOURCE"
git fetch --no-tags origin main
FETCHED_MAIN="$(git rev-parse origin/main)"
printf 'fetched_main=%s\n' "$FETCHED_MAIN"
[[ "$FETCHED_MAIN" == "$EXPECTED_TARGET_SHA" ]] || \
  stop "fetched origin/main does not match approved target"

git reset --hard "$EXPECTED_TARGET_SHA"
SOURCE_MOVED=1
[[ -z "$(git status --porcelain=v1)" ]] || stop "target checkout is not clean"
printf 'PASS: production checkout moved to approved target while old containers stayed live\n'

section "BUILD AND TEST CANDIDATE"
docker build \
  --build-arg "CACHEBUST=${EXPECTED_TARGET_SHA}" \
  --label "org.opencontainers.image.revision=${EXPECTED_TARGET_SHA}" \
  -t "$CANDIDATE_IMAGE" \
  .

CANDIDATE_IMAGE_ID="$(docker image inspect "$CANDIDATE_IMAGE" --format '{{.Id}}')"
printf 'candidate_image=%s\n' "$CANDIDATE_IMAGE"
printf 'candidate_image_id=%s\n' "$CANDIDATE_IMAGE_ID"

docker run -d \
  --name "$CANDIDATE_CONTAINER" \
  --env-file "${CANDIDATE_STATE_DIR}/.env" \
  -e APEXODDS_UI_HOST=0.0.0.0 \
  -e APEXODDS_UI_PORT=8787 \
  -e APEXODDS_DATA_DIR=/app/data \
  -e APEXODDS_LOG_DIR=/app/data/logs \
  -e PYTHONPATH=/app/src \
  -v "${CANDIDATE_STATE_DIR}/data:/app/data" \
  -v "${CANDIDATE_STATE_DIR}/secrets:/run/secrets:ro" \
  -p "127.0.0.1:${CANDIDATE_PORT}:8787" \
  "$CANDIDATE_IMAGE" >/dev/null
CANDIDATE_STARTED=1

wait_local_health "http://127.0.0.1:${CANDIDATE_PORT}/api/health" 60 || \
  stop "candidate health endpoint did not become ready"

CANDIDATE_LOGIN="$(mktemp)"
CANDIDATE_JS="$(mktemp)"
curl -fsS --connect-timeout 5 --max-time 20 \
  "http://127.0.0.1:${CANDIDATE_PORT}/login" -o "$CANDIDATE_LOGIN"
curl -fsS --connect-timeout 5 --max-time 20 \
  "http://127.0.0.1:${CANDIDATE_PORT}/static/analytics.js" -o "$CANDIDATE_JS"

grep -Fq '<script defer src="/static/analytics.js"></script>' "$CANDIDATE_LOGIN" || \
  stop "candidate login page does not load analytics"
grep -Fq "$EXPECTED_PROPERTY_ID" "$CANDIDATE_JS" || \
  stop "candidate analytics property ID is missing"
grep -Fq 'data-auto-track", "false"' "$CANDIDATE_JS" || \
  stop "candidate manual pageview mode is missing"
grep -Fq 'data-exclude-search", "true"' "$CANDIDATE_JS" || \
  stop "candidate query exclusion is missing"
grep -Fq 'data-exclude-hash", "true"' "$CANDIDATE_JS" || \
  stop "candidate hash exclusion is missing"

rm -f "$CANDIDATE_LOGIN" "$CANDIDATE_JS"
cleanup_candidate
printf 'PASS: isolated candidate passed health and analytics contract\n'

section "ACTIVATE"
ACTIVATED=1
docker image tag "$CANDIDATE_IMAGE" apexodds:latest

docker compose "${COMPOSE_ARGS[@]}" up -d --no-build --force-recreate \
  apexodds-ui apexodds-paper-learn

wait_local_health "http://127.0.0.1:8787/api/health" 90 || \
  rollback "new local health endpoint did not become ready"

for ((i = 1; i <= 60; i++)); do
  if curl -fsS --connect-timeout 3 --max-time 8 \
    "https://${EXPECTED_DOMAIN}/api/health" >/dev/null 2>&1; then
    break
  fi
  if (( i == 60 )); then
    rollback "new public health endpoint did not become ready"
  fi
  sleep 2
done

LIVE_LOGIN="$(mktemp)"
LIVE_JS="$(mktemp)"
curl -fsS --connect-timeout 5 --max-time 20 \
  "https://${EXPECTED_DOMAIN}/login" -o "$LIVE_LOGIN" || \
  rollback "public login page failed after activation"
curl -fsS --connect-timeout 5 --max-time 20 \
  "https://${EXPECTED_DOMAIN}/static/analytics.js" -o "$LIVE_JS" || \
  rollback "public analytics JavaScript failed after activation"

grep -Fq '<script defer src="/static/analytics.js"></script>' "$LIVE_LOGIN" || \
  rollback "public login page does not load analytics"
grep -Fq "$EXPECTED_PROPERTY_ID" "$LIVE_JS" || \
  rollback "public analytics property ID is missing"
grep -Fq 'data-auto-track", "false"' "$LIVE_JS" || \
  rollback "public manual pageview mode is missing"
grep -Fq 'data-exclude-search", "true"' "$LIVE_JS" || \
  rollback "public query exclusion is missing"
grep -Fq 'data-exclude-hash", "true"' "$LIVE_JS" || \
  rollback "public hash exclusion is missing"

rm -f "$LIVE_LOGIN" "$LIVE_JS"

[[ "$(git rev-parse HEAD)" == "$EXPECTED_TARGET_SHA" ]] || \
  rollback "production checkout does not match approved target"
[[ -z "$(git status --porcelain=v1)" ]] || \
  rollback "production checkout became dirty"

ENV_HASH_AFTER="$(sha256sum .env | awk '{print $1}')"
SECRETS_HASH_AFTER="$(
  find secrets -type f -print0 |
    sort -z |
    xargs -0 -r sha256sum |
    sha256sum |
    awk '{print $1}'
)"
[[ "$ENV_HASH_AFTER" == "$ENV_HASH_BEFORE" ]] || \
  rollback ".env changed during deployment"
[[ "$SECRETS_HASH_AFTER" == "$SECRETS_HASH_BEFORE" ]] || \
  rollback "secrets changed during deployment"

NEW_IMAGE_ID="$(docker image inspect apexodds:latest --format '{{.Id}}')"
[[ "$NEW_IMAGE_ID" == "$CANDIDATE_IMAGE_ID" ]] || \
  rollback "active image is not the validated candidate"

docker image rm "$CANDIDATE_IMAGE" >/dev/null 2>&1 || true
rm -rf "$CANDIDATE_STATE_DIR"

trap - ERR
printf '\nAPEXODDS ANALYTICS PRODUCTION ACTIVATION PASSED\n'
printf 'source_sha=%s\n' "$EXPECTED_TARGET_SHA"
printf 'active_image_id=%s\n' "$NEW_IMAGE_ID"
printf 'property_id=%s\n' "$EXPECTED_PROPERTY_ID"
printf 'rollback_image=%s\n' "$ROLLBACK_IMAGE"
printf 'backup=%s\n' "$BACKUP_DIR"
printf 'production_changed=YES\n'
