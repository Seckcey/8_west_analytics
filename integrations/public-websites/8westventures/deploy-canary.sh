#!/usr/bin/env bash
set -Eeuo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "ERROR: run as root." >&2; exit 1; }

SITE_ROOT="${SITE_ROOT:-/srv/8west/www/8westventures.com}"
CURRENT_LINK="$SITE_ROOT/current"
RELEASES_DIR="$SITE_ROOT/releases"
SOURCE_JS="${SOURCE_JS:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/main.js}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
NEW_RELEASE="$RELEASES_DIR/analytics-canary-$TIMESTAMP"
EXPECTED_WEBSITE_ID="508def7a-17a5-4510-a49b-a90c0cdafe76"
PREVIOUS_RELEASE=""
SWITCHED=0

cleanup() {
  if [[ "$SWITCHED" -eq 1 && -n "$PREVIOUS_RELEASE" ]]; then
    echo "ERROR: validation failed after release switch; restoring prior release." >&2
    ln -s "$PREVIOUS_RELEASE" "$CURRENT_LINK.rollback"
    mv -Tf "$CURRENT_LINK.rollback" "$CURRENT_LINK"
  fi
}
trap cleanup ERR

[[ -L "$CURRENT_LINK" ]] || { echo "ERROR: $CURRENT_LINK is not a symlink." >&2; exit 1; }
[[ -f "$SOURCE_JS" ]] || { echo "ERROR: missing reviewed source file $SOURCE_JS" >&2; exit 1; }

PREVIOUS_RELEASE="$(readlink -f "$CURRENT_LINK")"
[[ -d "$PREVIOUS_RELEASE" ]] || { echo "ERROR: current release target is invalid." >&2; exit 1; }
[[ -f "$PREVIOUS_RELEASE/public/index.html" ]] || { echo "ERROR: current index.html is missing." >&2; exit 1; }
[[ -f "$PREVIOUS_RELEASE/public/assets/js/main.js" ]] || { echo "ERROR: current main.js is missing." >&2; exit 1; }

install -d -m 0755 "$RELEASES_DIR"
cp -a "$PREVIOUS_RELEASE" "$NEW_RELEASE"
install -m 0644 -o root -g root "$SOURCE_JS" "$NEW_RELEASE/public/assets/js/main.js"

# Static privacy and configuration checks before release activation.
grep -Fq "https://analytics.8westventures.com/script.js" "$NEW_RELEASE/public/assets/js/main.js"
grep -Fq "$EXPECTED_WEBSITE_ID" "$NEW_RELEASE/public/assets/js/main.js"
grep -Fq 'data-domains", "8westventures.com,www.8westventures.com"' "$NEW_RELEASE/public/assets/js/main.js"
grep -Fq 'data-exclude-search", "true"' "$NEW_RELEASE/public/assets/js/main.js"
grep -Fq 'data-exclude-hash", "true"' "$NEW_RELEASE/public/assets/js/main.js"
grep -Fq 'contact_form_submitted' "$NEW_RELEASE/public/assets/js/main.js"
grep -Fq 'contact_form_failed' "$NEW_RELEASE/public/assets/js/main.js"

# Confirm form values are used only by the existing form provider/mail fallback,
# never as arguments to the analytics wrapper.
if grep -En 'trackEvent\([^\n]*(name|email|company|message|accessKey|payload|json)' "$NEW_RELEASE/public/assets/js/main.js"; then
  echo "ERROR: possible sensitive value in analytics call." >&2
  exit 1
fi

apache2ctl configtest

ln -s "$NEW_RELEASE" "$CURRENT_LINK.next"
mv -Tf "$CURRENT_LINK.next" "$CURRENT_LINK"
SWITCHED=1

curl -fsS --retry 5 --retry-delay 1 https://8westventures.com/ >/dev/null
curl -fsS --retry 5 --retry-delay 1 https://8westventures.com/assets/js/main.js \
  | grep -Fq "$EXPECTED_WEBSITE_ID"
curl -fsS --retry 5 --retry-delay 1 https://analytics.8westventures.com/script.js >/dev/null

SWITCHED=0
trap - ERR

echo "PASS: 8westventures.com analytics canary release activated"
echo "previous_release=$PREVIOUS_RELEASE"
echo "current_release=$NEW_RELEASE"
echo "rollback_command=ln -sfn '$PREVIOUS_RELEASE' '$CURRENT_LINK'"
