#!/usr/bin/env bash
set -Eeuo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "ERROR: run as root." >&2; exit 1; }

BACKUP_DIR="${BACKUP_DIR:-/var/backups/8west-analytics}"
POSTGRES_IMAGE="postgres:17.10-alpine3.23"
BACKUP_FILE="${1:-}"

if [[ -z "$BACKUP_FILE" ]]; then
  BACKUP_FILE="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'umami-*.dump' -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)"
fi

[[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]] || { echo "ERROR: no backup file found." >&2; exit 1; }
[[ -f "$BACKUP_FILE.sha256" ]] || { echo "ERROR: missing checksum file." >&2; exit 1; }

cd "$(dirname "$BACKUP_FILE")"
sha256sum --check "$(basename "$BACKUP_FILE.sha256")"

suffix="$(date -u +%s)-$$"
container="8west-analytics-restore-$suffix"
volume="8west-analytics-restore-$suffix"
restore_password="$(openssl rand -hex 24)"
start_epoch="$(date +%s)"

cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
  docker volume rm "$volume" >/dev/null 2>&1 || true
}
trap cleanup EXIT

umask 077
docker volume create "$volume" >/dev/null

docker run -d \
  --name "$container" \
  --network none \
  -e POSTGRES_DB=restore_validation \
  -e POSTGRES_USER=restore_validator \
  -e POSTGRES_PASSWORD="$restore_password" \
  -v "$volume:/var/lib/postgresql/data" \
  -v "$BACKUP_FILE:/restore/backup.dump:ro" \
  "$POSTGRES_IMAGE" >/dev/null

for attempt in $(seq 1 30); do
  if docker exec "$container" pg_isready -U restore_validator -d restore_validation >/dev/null 2>&1; then
    break
  fi
  if (( attempt == 30 )); then
    echo "ERROR: disposable PostgreSQL did not become ready." >&2
    docker logs --tail=100 "$container" >&2
    exit 1
  fi
  sleep 2
done

docker exec "$container" pg_restore \
  --exit-on-error \
  --no-owner \
  --no-acl \
  --username=restore_validator \
  --dbname=restore_validation \
  /restore/backup.dump

table_count="$(docker exec "$container" psql -At -U restore_validator -d restore_validation -c "select count(*) from information_schema.tables where table_schema='public';")"
[[ "$table_count" =~ ^[0-9]+$ && "$table_count" -gt 0 ]] || { echo "ERROR: restored database contains no public tables." >&2; exit 1; }

end_epoch="$(date +%s)"
echo "PASS: disposable restore succeeded"
echo "backup=$BACKUP_FILE"
echo "public_tables=$table_count"
echo "duration_seconds=$((end_epoch - start_epoch))"
