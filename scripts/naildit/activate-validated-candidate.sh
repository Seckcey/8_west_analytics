#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_PUBLIC_IP="173.255.206.232"
FRONTEND="/opt/naildit/frontend"
LIVE_DIST="$FRONTEND/dist"
CANDIDATE="${1:-}"
FRONTEND_SERVICE="naildit-frontend.service"
BACKEND_SERVICE="naildit-backend.service"
DOMAIN="naildit.8westventures.com"
EXPECTED_PROPERTY_ID="ea32b4fe-d902-4a69-a7a1-ede08162485b"
EXPECTED_JS="/assets/index-B2vshX9H.js"
EXPECTED_CSS="/assets/index-GEVXK-pz.css"
APPROVED_MERGE_SHA="5834015e7f94356ae12df460208d17c17be7fa6b"
ARTIFACT_SHA="b5b04868d3c2aa81dbd0b3eb78593c52f23cd57fcf46576df1846d6f9edc828d"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ROLLBACK_DIST="$FRONTEND/dist.rollback-$STAMP"
FAILED_DIST="$FRONTEND/dist.failed-$STAMP"
BACKUP="/var/backups/8west-analytics-integrations/naildit-$STAMP"
TEMP="/tmp/naildit-activation-$STAMP"
SWAP_STARTED=0

log() {
    printf '%s\n' "$*"
}

wait_for_frontend() {
    local attempt direct_status public_status

    for attempt in $(seq 1 45); do
        direct_status="$(
            curl --silent --output /dev/null --write-out '%{http_code}' \
                --connect-timeout 2 --max-time 5 \
                http://172.18.0.1:4173/ 2>/dev/null || true
        )"

        public_status="$(
            curl --silent --output /dev/null --write-out '%{http_code}' \
                --connect-timeout 3 --max-time 8 \
                "https://$DOMAIN/" 2>/dev/null || true
        )"

        if systemctl is-active --quiet "$FRONTEND_SERVICE" \
            && ss -lntp | grep -Eq '172\.18\.0\.1:4173[[:space:]]' \
            && [[ "$direct_status" == "200" ]] \
            && [[ "$public_status" == "200" ]]; then
            return 0
        fi

        sleep 1
    done

    return 1
}

rollback_and_exit() {
    local status="$1"
    local reason="$2"

    trap - ERR
    set +e

    log ""
    log "ROLLBACK STARTED"
    log "reason=$reason"

    if [[ "$SWAP_STARTED" -eq 1 ]]; then
        systemctl stop "$FRONTEND_SERVICE"

        if [[ -d "$ROLLBACK_DIST" ]]; then
            if [[ -d "$LIVE_DIST" ]]; then
                if [[ ! -e "$FAILED_DIST" ]]; then
                    mv "$LIVE_DIST" "$FAILED_DIST"
                else
                    rm -rf "$LIVE_DIST"
                fi
            fi

            mv "$ROLLBACK_DIST" "$LIVE_DIST"
        fi

        systemctl start "$FRONTEND_SERVICE"

        if wait_for_frontend; then
            log "ROLLBACK PASSED: previous frontend restored"
        else
            log "CRITICAL: previous files were restored but health did not recover"
        fi
    else
        log "ROLLBACK NOT NEEDED: activation had not started"
    fi

    rm -rf "$TEMP"
    log "backup=$BACKUP"
    exit "$status"
}

on_error() {
    local status="$1"
    local line="$2"
    local command="$3"
    rollback_and_exit "$status" "line=$line command=$command"
}

fail() {
    rollback_and_exit 1 "$1"
}

trap 'status=$?; line=$LINENO; command=$BASH_COMMAND; on_error "$status" "$line" "$command"' ERR

[[ "$EUID" -eq 0 ]] || fail "run this script with sudo"
[[ -n "$CANDIDATE" ]] || fail "candidate directory argument is required"
[[ "$CANDIDATE" == "$FRONTEND"/dist.candidate-* ]] || fail "candidate path is outside the approved frontend directory"
[[ "$CANDIDATE" != "$LIVE_DIST" ]] || fail "candidate cannot be the live directory"

install -d -m 0700 "$TEMP"

log "===== 1. IDENTITY AND HEALTH ====="
PUBLIC_IP="$(
    curl -4 -fsS --connect-timeout 10 --max-time 20 \
        https://checkip.amazonaws.com | tr -d '\r\n'
)"
log "public_ip=$PUBLIC_IP"
[[ "$PUBLIC_IP" == "$EXPECTED_PUBLIC_IP" ]] || fail "wrong server"
[[ -d "$LIVE_DIST" ]] || fail "live frontend directory is missing"
[[ -d "$CANDIDATE" ]] || fail "validated candidate directory is missing"
systemctl is-active --quiet "$FRONTEND_SERVICE" || fail "frontend service is not active"
systemctl is-active --quiet "$BACKEND_SERVICE" || fail "backend service is not active"
[[ "$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 20 "https://$DOMAIN/")" == "200" ]] || fail "homepage is not healthy"
[[ "$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 20 "https://$DOMAIN/api/health")" == "200" ]] || fail "API health is not healthy"
log "PASS: correct server and healthy production"

log ""
log "===== 2. CANDIDATE CONTRACT ====="
[[ ! -e "$ROLLBACK_DIST" ]] || fail "rollback destination already exists"
[[ ! -e "$FAILED_DIST" ]] || fail "failed-candidate destination already exists"
[[ "$(stat -c '%d' "$LIVE_DIST")" == "$(stat -c '%d' "$CANDIDATE")" ]] || fail "candidate and live directories are on different filesystems"

find "$CANDIDATE" -mindepth 1 -type f -printf '%P\n' | sort > "$TEMP/actual-files.txt"
cat > "$TEMP/expected-files.txt" <<'EOF'
assets/index-B2vshX9H.js
assets/index-GEVXK-pz.css
brand/naildit-favicon.png
brand/naildit-logo-square.png
favicon.svg
index.html
EOF
sort -o "$TEMP/expected-files.txt" "$TEMP/expected-files.txt"
diff -u "$TEMP/expected-files.txt" "$TEMP/actual-files.txt" || fail "candidate file list changed"

SPECIAL_FILE="$(find "$CANDIDATE" -mindepth 1 ! -type f ! -type d -print -quit)"
[[ -z "$SPECIAL_FILE" ]] || fail "candidate contains a special file"
grep -Fq "$EXPECTED_PROPERTY_ID" "$CANDIDATE$EXPECTED_JS" || fail "candidate property ID changed"
grep -Fq 'https://analytics.8westventures.com/script.js' "$CANDIDATE$EXPECTED_JS" || fail "candidate tracker URL changed"
grep -Fq "src=\"$EXPECTED_JS\"" "$CANDIDATE/index.html" || fail "candidate JavaScript reference changed"
grep -Fq "href=\"$EXPECTED_CSS\"" "$CANDIDATE/index.html" || fail "candidate CSS reference changed"
log "PASS: validated candidate contract remains intact"

log ""
log "===== 3. BACKUP ====="
install -d -m 0750 "$BACKUP"
tar -C "$FRONTEND" -czf "$BACKUP/previous-dist.tar.gz" dist
find "$LIVE_DIST" -type f -print0 | sort -z | xargs -0 -r sha256sum > "$BACKUP/previous-dist-sha256.txt"
find "$CANDIDATE" -type f -print0 | sort -z | xargs -0 -r sha256sum > "$BACKUP/candidate-dist-sha256.txt"
systemctl cat "$FRONTEND_SERVICE" > "$BACKUP/frontend-systemd-unit.txt"
systemctl cat "$BACKEND_SERVICE" > "$BACKUP/backend-systemd-unit.txt"
cat > "$BACKUP/deployment-record.txt" <<EOF
deployment_time_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
domain=$DOMAIN
approved_merge_sha=$APPROVED_MERGE_SHA
artifact_sha256=$ARTIFACT_SHA
property_id=$EXPECTED_PROPERTY_ID
candidate_directory=$CANDIDATE
rollback_directory=$ROLLBACK_DIST
deployment_method=validated_atomic_candidate_swap
EOF
log "backup=$BACKUP"
log "PASS: rollback backup created"

log ""
log "===== 4. ACTIVATE ====="
systemctl stop "$FRONTEND_SERVICE"
mv "$LIVE_DIST" "$ROLLBACK_DIST"
SWAP_STARTED=1
mv "$CANDIDATE" "$LIVE_DIST"
systemctl start "$FRONTEND_SERVICE"
wait_for_frontend || fail "new frontend did not become healthy"
log "PASS: validated candidate activated"

log ""
log "===== 5. PUBLIC ACCEPTANCE ====="
curl -fsS --retry 5 --retry-delay 1 "https://$DOMAIN/?deployment=$STAMP" -o "$TEMP/live.html"
grep -Fq '<div id="root"></div>' "$TEMP/live.html" || fail "public React root is missing"
grep -Fq "$EXPECTED_JS" "$TEMP/live.html" || fail "public HTML references the wrong JavaScript asset"
curl -fsS --retry 5 --retry-delay 1 "https://$DOMAIN$EXPECTED_JS?deployment=$STAMP" -o "$TEMP/live.js"
grep -Fq "$EXPECTED_PROPERTY_ID" "$TEMP/live.js" || fail "public JavaScript has the wrong property ID"
grep -Fq 'https://analytics.8westventures.com/script.js' "$TEMP/live.js" || fail "public JavaScript has the wrong analytics server"
[[ "$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 20 "https://$DOMAIN/api/health")" == "200" ]] || fail "API health failed after activation"
systemctl is-active --quiet "$FRONTEND_SERVICE" || fail "frontend service stopped after activation"
systemctl is-active --quiet "$BACKEND_SERVICE" || fail "backend service stopped after activation"
curl -fsS --connect-timeout 5 --max-time 20 https://analytics.8westventures.com/script.js >/dev/null || fail "central analytics script is unavailable"
log "PASS: public frontend, backend, and analytics contract accepted"

SWAP_STARTED=0
trap - ERR
rm -rf "$TEMP"

log ""
log "NAILDIT PRODUCTION ACTIVATION PASSED"
log "live_directory=$LIVE_DIST"
log "rollback_directory=$ROLLBACK_DIST"
log "backup=$BACKUP"
log "javascript_asset=$EXPECTED_JS"
log "property_id=$EXPECTED_PROPERTY_ID"
