#!/usr/bin/env bash
set -Eeuo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "ERROR: run as root." >&2; exit 1; }

APP_DIR="${APP_DIR:-/opt/8west-analytics}"

install -m 0755 -o root -g root "$APP_DIR/operations/backup-postgres.sh" /usr/local/sbin/8west-analytics-backup
install -m 0755 -o root -g root "$APP_DIR/operations/prune-backups.sh" /usr/local/sbin/8west-analytics-prune-backups

sed "s#ExecStart=/opt/8west-analytics/operations/backup-postgres.sh#ExecStart=/usr/local/sbin/8west-analytics-backup#; s#ExecStartPost=/opt/8west-analytics/operations/prune-backups.sh#ExecStartPost=/usr/local/sbin/8west-analytics-prune-backups#" \
  "$APP_DIR/systemd/8west-analytics-backup.service" \
  > /etc/systemd/system/8west-analytics-backup.service

install -m 0644 -o root -g root \
  "$APP_DIR/systemd/8west-analytics-backup.timer" \
  /etc/systemd/system/8west-analytics-backup.timer

systemctl daemon-reload
systemctl enable --now 8west-analytics-backup.timer

echo "PASS: backup timer installed"
systemctl list-timers 8west-analytics-backup.timer --no-pager
