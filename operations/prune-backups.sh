#!/usr/bin/env bash
set -Eeuo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "ERROR: run as root." >&2; exit 1; }

BACKUP_DIR="${BACKUP_DIR:-/var/backups/8west-analytics}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

[[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || { echo "ERROR: RETENTION_DAYS must be numeric." >&2; exit 1; }
[[ -d "$BACKUP_DIR" ]] || { echo "No backup directory; nothing to prune."; exit 0; }

mapfile -t valid_backups < <(
  find "$BACKUP_DIR" -maxdepth 1 -type f -name 'umami-*.dump' -printf '%T@ %p\n' \
    | sort -nr \
    | cut -d' ' -f2-
)

if (( ${#valid_backups[@]} == 0 )); then
  echo "No backups found; nothing to prune."
  exit 0
fi

newest="${valid_backups[0]}"
echo "Protected newest backup: $newest"

deleted=0
while IFS= read -r -d '' backup; do
  [[ "$backup" == "$newest" ]] && continue
  checksum="$backup.sha256"
  rm -f -- "$backup" "$checksum"
  echo "Deleted expired backup: $backup"
  deleted=$((deleted + 1))
done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'umami-*.dump' -mtime "+$RETENTION_DAYS" -print0)

echo "PASS: retention complete; deleted=$deleted retention_days=$RETENTION_DAYS"
