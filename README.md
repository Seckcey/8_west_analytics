# 8 West Analytics

Self-hosted, privacy-conscious analytics infrastructure and governance for websites and applications owned by 8 West Ventures, LLC and related businesses.

## Status

The dedicated pre-v1 Umami platform is deployed at `analytics.8westventures.com` on AWS EC2. HTTPS, private PostgreSQL networking, reboot recovery, nightly logical backups, checksums, and disposable restore validation have passed.

The first production website canary, `8westventures.com`, was activated and browser-validated on July 20, 2026. It records automatic page views and a tightly approved set of anonymous categorical events. Search parameters, hash fragments, form contents, identifiers, Session Replay, heatmaps, form capture, and keystroke capture remain excluded or prohibited.

The platform remains pre-v1, and downtime is acceptable until Frankie and Mary approve the broader launch gate. Additional properties or events require separate approval and validation.

## Governance

Frankie and Mary make all product, architecture, privacy, scope, infrastructure, and approval decisions. Development agents may inspect, plan, implement, test, and document work, but must not make unapproved product or infrastructure decisions.

## Safety boundary

This repository must never contain production credentials, database passwords, API secrets, authentication tokens, customer data, patient data, mailbox data, device identifiers, or raw sensitive analytics exports.
