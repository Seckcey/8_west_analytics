# Backup and Restore

## Scope

This procedure protects the self-hosted Umami PostgreSQL database. It does not modify application repositories or website integrations.

## Approved pre-v1 backup model

The approved pre-v1 design uses two layers:

1. nightly local PostgreSQL logical backups under `/var/backups/8west-analytics`;
2. EC2/EBS snapshots managed through AWS by Frankie.

No separate S3 bucket, external backup provider, or custom upload pipeline is required before v1.0.

AWS does not create EBS snapshots automatically unless a manual or scheduled snapshot mechanism is configured. The EC2/EBS snapshot schedule and retention are managed outside this repository.

## Local backup

Run as root:

```bash
sudo /opt/8west-analytics/operations/backup-postgres.sh
```

The script writes a PostgreSQL custom-format dump and matching SHA-256 checksum under `/var/backups/8west-analytics`. Files are owned by `root:root` with mode `0600`.

The backup is accepted only when it is non-empty and version-matched PostgreSQL 17 `pg_restore --list` can parse it.

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

Local logical backups provide database-level recovery. EC2/EBS snapshots provide the approved infrastructure-level recovery layer before v1.0.

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
