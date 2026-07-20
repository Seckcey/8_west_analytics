# Operations

## Approved pre-v1 controls

- nightly PostgreSQL logical backups
- SHA-256 checksum validation
- disposable PostgreSQL restore testing
- EC2/EBS snapshots managed through AWS by Frankie
- Docker health checks and restart policies
- Caddy supervision through systemd
- controlled upgrade and rollback procedures
- reasonable Docker and service log rotation
- manual capacity checks during development

## Deferred until a later approval

The following are not required before v1.0:

- separate S3 or external backup uploads
- CloudWatch agent installation
- custom memory, swap, disk, database-growth, or container metrics
- external uptime monitoring
- custom alerting infrastructure

Standard EC2 metrics do not include all guest operating-system and application signals. Manual checks are accepted during pre-v1 development because downtime is permitted and the system is not yet serving customers.

Analytics failures must never block an application workflow.
