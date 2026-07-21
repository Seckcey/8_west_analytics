#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_PUBLIC_IP="13.52.91.237"
APP_ROOT="/srv/8west/apps/milepost"
CURRENT="$APP_ROOT/current"
DOMAIN="support.8westit.com"

BASE_RENDER_BLOB="95c22445a8496851a1d1e7d70e1944b990ff6050"
BASE_LOGIN_BLOB="fe3d1463c4a62922810707880ce33160762a6ad0"
DEPLOYED_RENDER_BLOB="20b73560df5b426b276b54836e878b040430533d"
DEPLOYED_LOGIN_BLOB="c967026b711ebbee1032a710b51b407722a56dc5"
ANALYTICS_BLOB="87360a8330c1ace2f392e4923b99cac719c47530"

fail() {
    printf 'STOP: %s\n' "$*" >&2
    exit 1
}

file_blob() {
    git hash-object "$1"
}

printf '%s\n' '===== SERVER IDENTITY ====='
PUBLIC_IP="$(curl -4 -fsS --connect-timeout 10 --max-time 20 https://checkip.amazonaws.com | tr -d '\r\n')"
printf 'hostname=%s\n' "$(hostname)"
printf 'public_ip=%s\n' "$PUBLIC_IP"
[[ "$PUBLIC_IP" == "$EXPECTED_PUBLIC_IP" ]] || fail "wrong server"

printf '\n%s\n' '===== RELEASE LAYOUT ====='
[[ -L "$CURRENT" ]] || fail "$CURRENT is not a symlink"
LIVE_RELEASE="$(readlink -f "$CURRENT")"
[[ -d "$LIVE_RELEASE" ]] || fail "current release target is missing"
case "$LIVE_RELEASE" in
    "$APP_ROOT"/releases/*) ;;
    *) fail "current target is outside the Milepost releases directory" ;;
esac
printf 'current_symlink=%s\n' "$(readlink "$CURRENT")"
printf 'live_release=%s\n' "$LIVE_RELEASE"
printf 'release_owner=%s\n' "$(stat -c '%U:%G' "$LIVE_RELEASE")"
printf 'release_mode=%s\n' "$(stat -c '%a' "$LIVE_RELEASE")"
df -h "$APP_ROOT" | tail -1

RENDER="$LIVE_RELEASE/lib/render.php"
LOGIN="$LIVE_RELEASE/public/login.php"
ANALYTICS="$LIVE_RELEASE/public/assets/js/analytics.js"
[[ -f "$RENDER" ]] || fail "render.php is missing"
[[ -f "$LOGIN" ]] || fail "login.php is missing"

printf '\n%s\n' '===== LIVE FILE CLASSIFICATION ====='
RENDER_BLOB="$(file_blob "$RENDER")"
LOGIN_BLOB="$(file_blob "$LOGIN")"
ANALYTICS_BLOB_ACTUAL="absent"
[[ ! -e "$ANALYTICS" ]] || ANALYTICS_BLOB_ACTUAL="$(file_blob "$ANALYTICS")"
printf 'render_blob=%s\n' "$RENDER_BLOB"
printf 'login_blob=%s\n' "$LOGIN_BLOB"
printf 'analytics_blob=%s\n' "$ANALYTICS_BLOB_ACTUAL"

STATE=""
if [[ "$RENDER_BLOB" == "$BASE_RENDER_BLOB" \
      && "$LOGIN_BLOB" == "$BASE_LOGIN_BLOB" \
      && "$ANALYTICS_BLOB_ACTUAL" == "absent" ]]; then
    STATE="ready_for_analytics"
elif [[ "$RENDER_BLOB" == "$DEPLOYED_RENDER_BLOB" \
        && "$LOGIN_BLOB" == "$DEPLOYED_LOGIN_BLOB" \
        && "$ANALYTICS_BLOB_ACTUAL" == "$ANALYTICS_BLOB" ]]; then
    STATE="already_deployed"
else
    fail "live files do not match either the approved pre-analytics baseline or approved deployed state"
fi
printf 'classification=%s\n' "$STATE"

printf '\n%s\n' '===== PHP AND APACHE ====='
php -l "$RENDER"
php -l "$LOGIN"
apache2ctl configtest
apache2ctl -S 2>&1 | grep -E 'support\.8westit\.com|port 443' || true

printf '\n%s\n' '===== PUBLIC HEALTH ====='
ROOT_HEADERS="$(mktemp)"
trap 'rm -f "$ROOT_HEADERS"' EXIT
curl -fsS -D "$ROOT_HEADERS" -o /dev/null --connect-timeout 5 --max-time 20 "https://$DOMAIN/"
ROOT_STATUS="$(awk 'toupper($1) ~ /^HTTP\// {code=$2} END {print code}' "$ROOT_HEADERS")"
ROOT_LOCATION="$(awk 'BEGIN{IGNORECASE=1} /^location:/ {sub(/\r$/, "", $2); print $2}' "$ROOT_HEADERS" | tail -1)"
LOGIN_STATUS="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 20 "https://$DOMAIN/login.php")"
printf 'root_status=%s\n' "$ROOT_STATUS"
printf 'root_location=%s\n' "$ROOT_LOCATION"
printf 'login_status=%s\n' "$LOGIN_STATUS"
[[ "$ROOT_STATUS" == "302" ]] || fail "root did not return HTTP 302"
[[ "$ROOT_LOCATION" == *"login.php"* ]] || fail "root did not redirect to login.php"
[[ "$LOGIN_STATUS" == "200" ]] || fail "login.php did not return HTTP 200"

printf '\n%s\n' 'MILEPOST ANALYTICS PREFLIGHT PASSED'
printf 'classification=%s\n' "$STATE"
printf 'live_release=%s\n' "$LIVE_RELEASE"
printf 'production_changed=NO\n'
