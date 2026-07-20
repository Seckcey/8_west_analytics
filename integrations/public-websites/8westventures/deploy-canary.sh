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
  rm -f "$CURRENT_LINK.next" "$CURRENT_LINK.rollback"
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

python3 - "$NEW_RELEASE/public/assets/js/main.js" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
for payload in re.findall(r'trackEvent\(\s*"[^"]+"\s*,\s*\{(.*?)\}\s*\)', text, flags=re.S):
    forbidden = [
        "data.name",
        "data.email",
        "data.company",
        "data.message",
        "form.name",
        "form.email",
        "form.company",
        "form.message",
        "accessKey",
        "payload",
        "json.",
    ]
    found = [token for token in forbidden if token in payload]
    if found:
        raise SystemExit(f"ERROR: sensitive token in analytics payload: {found}")
print("PASS: analytics payloads contain no form-value variables")
PY

apache2ctl configtest

rm -f "$CURRENT_LINK.next" "$CURRENT_LINK.rollback"
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
