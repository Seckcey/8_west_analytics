# Backup and Restore

## Scope

This procedure protects the self-hosted Umami PostgreSQL database. It does not modify application repositories or website integrations.

## Local backup

Run as root:

```bash
sudo /opt/8west-analytics/operations/backup-postgres.sh
```

The script writes a PostgreSQL custom-format dump and matching SHA-256 checksum under `/var/backups/8west-analytics`. Files are owned by `root:root` with mode `0600`.

The backup is accepted only when it is non-empty and `pg_restore --list` can parse it.

## Disposable restore validation

Run as root:

```bash
sudo /opt/8west-analytics/operations/restore-postgres-test.sh
```

The newest backup is selected automatically. A specific backup may be supplied as the first argument.

The restore test:

1. verifies the SHA-256 checksum;
2. creates a temporary PostgreSQL 17 container and volume;
3. attaches no network to the disposable container;
4. restores the dump with `--exit-on-error`;
5. confirms that public-schema tables exist;
6. removes the temporary container and volume.

It does not connect to or alter the live PostgreSQL container or volume.

## Retention

The default local retention is 14 days. The newest backup is always protected even if it is older than the retention threshold.

```bash
sudo RETENTION_DAYS=14 /opt/8west-analytics/operations/prune-backups.sh
```

Local retention is not a substitute for an approved off-instance backup target.

## Nightly timer

Install after a manual backup and disposable restore both pass:

```bash
sudo /opt/8west-analytics/operations/install-backup-timer.sh
```

The timer runs nightly at 03:15 UTC with up to 15 minutes of randomized delay and is persistent across downtime.

Check it with:

```bash
systemctl list-timers 8west-analytics-backup.timer --no-pager
sudo systemctl status 8west-analytics-backup.timer --no-pager
sudo journalctl -u 8west-analytics-backup.service -n 100 --no-pager
```

## Production recovery

A production restore is intentionally not automated by these scripts. It requires an approved recovery window, a fresh backup of the current state where possible, explicit identification of the target dump, and Frankie and Mary approval before replacing the live database.
