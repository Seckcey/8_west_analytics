# Architecture Overview

## Status

Approved pre-v1 architecture. Frankie and Mary retain authority over all production launch, privacy, scope, and infrastructure decisions.

## Initial topology

- Dedicated AWS EC2 instance
- Ubuntu 24.04 LTS
- AMD64 t3.micro canary
- Encrypted gp3 storage
- Docker Engine and Docker Compose
- Host-installed Caddy reverse proxy and TLS
- Self-hosted Umami
- Private PostgreSQL container network
- Nightly local PostgreSQL logical backups with tested disposable restore
- EC2/EBS snapshots managed through AWS as the infrastructure backup layer

## Backup decision

No separate S3 bucket, external backup provider, or custom off-instance upload pipeline is required before v1.0. Frankie is managing infrastructure backups through EC2/EBS snapshots. The repository retains version-matched PostgreSQL logical backups because they provide database-level recovery independent of a full-volume restore.

## Monitoring decision

No CloudWatch agent, custom metrics, external uptime service, or dedicated alert stack is required before v1.0. The deployment retains Docker health checks, restart policies, Caddy service supervision, systemd backup scheduling, and manual operational verification.

Standard EC2 metrics remain available for host-level infrastructure visibility. Guest memory, swap, container health, application heartbeat, and backup age are not assumed to be covered by default EC2 metrics and may be checked manually until a later monitoring decision is approved.

## Reliability boundary

Analytics must fail open. Analytics outages must not block websites, forms, authentication, remote operations, or other business workflows.

Pre-v1 downtime is acceptable. Correctness, privacy, backup validation, and clean recovery take priority over availability until Frankie and Mary approve the v1.0 launch gate.

## Prohibited architecture

Do not place Umami on the Milepost production server without explicit approval.
