# Architecture Overview

## Status

Proposed. Deployment requires explicit approval from Frankie and Mary.

## Initial topology

- Dedicated AWS EC2 instance
- Ubuntu 24.04 LTS
- AMD64 t3.micro canary
- Encrypted gp3 storage
- Docker Engine and Docker Compose
- Caddy reverse proxy and TLS
- Self-hosted Umami
- Private PostgreSQL container network
- Off-instance encrypted backups

## Reliability boundary

Analytics must fail open. Analytics outages must not block websites, forms, authentication, remote operations, or other business workflows.

## Prohibited architecture

Do not place Umami on the Milepost production server without explicit approval.
