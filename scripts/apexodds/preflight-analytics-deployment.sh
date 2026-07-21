#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_PUBLIC_IP="35.172.195.208"
EXPECTED_DOMAIN="apexodds.8westventures.com"
EXPECTED_TARGET_SHA="2fad7675cb8d07f0590dc1edb432f471913f5680"
EXPECTED_PROPERTY_ID="d1f9c3cd-1115-4037-a679-cea8bf9bd09c"
COMPOSE_ARGS=(-f docker-compose.yml -f docker-compose.https.yml)

stop() {
  printf 'STOP: %s\n' "$*" >&2
  printf 'production_changed=NO\n' >&2
  exit 1
}

redact_remote() {
  sed -E 's#(https://)[^/@]+@#\1REDACTED@#; s#(https://[^/:]+:)[^@]+@#\1REDACTED@#'
}

find_app_dir() {
  local candidate
  for candidate in \
    "${APEXODDS_APP_DIR:-}" \
    "$HOME/apexodds" \
    "/home/ubuntu/apexodds" \
    "/opt/apexodds"
  do
    [[ -n "$candidate" ]] || continue
    if [[ -d "$candidate/.git" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

printf '===== SERVER IDENTITY =====\n'
hostname
PUBLIC_IP="$(curl -4 -fsS --connect-timeout 10 --max-time 20 https://checkip.amazonaws.com | tr -d '[:space:]')"
printf 'public_ip=%s\n' "$PUBLIC_IP"
[[ "$PUBLIC_IP" == "$EXPECTED_PUBLIC_IP" ]] || stop "wrong server: expected $EXPECTED_PUBLIC_IP"

printf '\n===== APPLICATION CHECKOUT =====\n'
APP_DIR="$(find_app_dir)" || stop "ApexOdds Git checkout not found in approved locations"
printf 'app_dir=%s\n' "$APP_DIR"
cd "$APP_DIR"

for required in \
  docker-compose.yml \
  docker-compose.https.yml \
  Dockerfile \
  pyproject.toml \
  src/apexodds/web/app.py
  do
  [[ -f "$required" ]] || stop "missing required repository file: $required"
done

CURRENT_BRANCH="$(git branch --show-current)"
CURRENT_HEAD="$(git rev-parse HEAD)"
printf 'current_branch=%s\n' "${CURRENT_BRANCH:-DETACHED}"
printf 'current_head=%s\n' "$CURRENT_HEAD"
printf 'origin=%s\n' "$(git remote get-url origin | redact_remote)"

STATUS="$(git status --porcelain=v1)"
if [[ -n "$STATUS" ]]; then
  printf '%s\n' "$STATUS"
  stop "production checkout is not clean"
fi
printf 'worktree_clean=YES\n'

REMOTE_MAIN="$(git ls-remote --exit-code origin refs/heads/main | awk '{print $1}')" || stop "could not read origin/main with existing Git credentials"
printf 'remote_main=%s\n' "$REMOTE_MAIN"
[[ "$REMOTE_MAIN" == "$EXPECTED_TARGET_SHA" ]] || stop "origin/main moved; expected $EXPECTED_TARGET_SHA"

if git cat-file -e "${EXPECTED_TARGET_SHA}^{commit}" 2>/dev/null; then
  printf 'target_commit_local=YES\n'
else
  printf 'target_commit_local=NO\n'
fi

printf '\n===== PERSISTENT STATE BOUNDARY =====\n'
[[ -f .env ]] || stop ".env is missing"
[[ -d data ]] || stop "data directory is missing"
[[ -d secrets ]] || stop "secrets directory is missing"
stat -c 'env type=%F mode=%a owner=%U group=%G' .env
stat -c 'data type=%F mode=%a owner=%U group=%G' data
stat -c 'secrets type=%F mode=%a owner=%U group=%G' secrets
du -sh data secrets 2>/dev/null || true
printf 'persistent_files_read=NO\n'

echo
printf '===== DOCKER COMPOSE =====\n'
command -v docker >/dev/null 2>&1 || stop "docker is not installed"
docker compose version
SERVICES="$(docker compose "${COMPOSE_ARGS[@]}" config --services)" || stop "compose configuration is invalid"
printf '%s\n' "$SERVICES"
for expected_service in apexodds-ui apexodds-paper-learn caddy; do
  grep -Fxq "$expected_service" <<<"$SERVICES" || stop "compose service missing: $expected_service"
done

printf '\n===== CONTAINER STATE =====\n'
docker ps -a \
  --filter name=apexodds-ui \
  --filter name=apexodds-paper-learn \
  --filter name=apexodds-caddy \
  --format 'container={{.Names}} status={{.Status}} image={{.Image}}'

for container in apexodds-ui apexodds-paper-learn apexodds-caddy; do
  RUNNING="$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)"
  [[ "$RUNNING" == "true" ]] || stop "container not running: $container"
done

UI_HEALTH="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' apexodds-ui)"
printf 'ui_health=%s\n' "$UI_HEALTH"
[[ "$UI_HEALTH" == "healthy" ]] || stop "apexodds-ui is not healthy"

docker image inspect apexodds:latest \
  --format 'current_image_id={{.Id}} current_image_created={{.Created}}' \
  2>/dev/null || stop "apexodds:latest image is missing"

printf '\n===== HEALTH ENDPOINTS =====\n'
LOCAL_STATUS="$(curl -sS -o /tmp/apexodds-preflight-local-health.json -w '%{http_code}' --connect-timeout 5 --max-time 20 http://127.0.0.1:8787/api/health)"
PUBLIC_STATUS="$(curl -sS -o /tmp/apexodds-preflight-public-health.json -w '%{http_code}' --connect-timeout 5 --max-time 20 "https://${EXPECTED_DOMAIN}/api/health")"
printf 'local_health_status=%s\n' "$LOCAL_STATUS"
printf 'public_health_status=%s\n' "$PUBLIC_STATUS"
[[ "$LOCAL_STATUS" == "200" ]] || stop "local health endpoint failed"
[[ "$PUBLIC_STATUS" == "200" ]] || stop "public health endpoint failed"

python3 - <<'PY'
import json
from pathlib import Path
for label, filename in (
    ("local", "/tmp/apexodds-preflight-local-health.json"),
    ("public", "/tmp/apexodds-preflight-public-health.json"),
):
    payload = json.loads(Path(filename).read_text(encoding="utf-8"))
    print(f"{label}_version={payload.get('version')}")
    print(f"{label}_health_ok={payload.get('ok', payload.get('status'))}")
PY

printf '\n===== LIVE ANALYTICS STATE =====\n'
LOGIN_HTML="$(mktemp)"
ANALYTICS_JS="$(mktemp)"
trap 'rm -f "$LOGIN_HTML" "$ANALYTICS_JS" /tmp/apexodds-preflight-local-health.json /tmp/apexodds-preflight-public-health.json' EXIT

LOGIN_STATUS="$(curl -sS -o "$LOGIN_HTML" -w '%{http_code}' --connect-timeout 5 --max-time 20 "https://${EXPECTED_DOMAIN}/login")"
JS_STATUS="$(curl -sS -o "$ANALYTICS_JS" -w '%{http_code}' --connect-timeout 5 --max-time 20 "https://${EXPECTED_DOMAIN}/static/analytics.js")"
printf 'login_status=%s\n' "$LOGIN_STATUS"
printf 'analytics_js_status=%s\n' "$JS_STATUS"
[[ "$LOGIN_STATUS" == "200" ]] || stop "public login page failed"

TAG_PRESENT=NO
PROPERTY_PRESENT=NO
if grep -Fq '<script defer src="/static/analytics.js"></script>' "$LOGIN_HTML"; then
  TAG_PRESENT=YES
fi
if [[ "$JS_STATUS" == "200" ]] && grep -Fq "$EXPECTED_PROPERTY_ID" "$ANALYTICS_JS"; then
  PROPERTY_PRESENT=YES
fi
printf 'analytics_tag_present=%s\n' "$TAG_PRESENT"
printf 'analytics_property_present=%s\n' "$PROPERTY_PRESENT"

printf '\n===== DISK AND BACKUP READINESS =====\n'
df -h "$APP_DIR" /var/backups 2>/dev/null || df -h "$APP_DIR"
if [[ -d /var/backups/8west-analytics-integrations ]]; then
  stat -c 'backup_root mode=%a owner=%U group=%G' /var/backups/8west-analytics-integrations
else
  printf 'backup_root=ABSENT_WILL_CREATE_DURING_ACTIVATION\n'
fi

printf '\nAPEXODDS ANALYTICS PREFLIGHT PASSED\n'
printf 'target_sha=%s\n' "$EXPECTED_TARGET_SHA"
printf 'current_head=%s\n' "$CURRENT_HEAD"
if [[ "$CURRENT_HEAD" == "$EXPECTED_TARGET_SHA" && "$TAG_PRESENT" == "YES" && "$PROPERTY_PRESENT" == "YES" ]]; then
  printf 'classification=already_deployed\n'
else
  printf 'classification=ready_for_controlled_deployment\n'
fi
printf 'production_changed=NO\n'
