# SpineSync analytics production acceptance

- Property: `spinesync.8westit.com`
- Umami property ID: `664a6d75-4400-4d56-b00a-4de12cdfa5a2`
- Source repository: `Seckcey/spine_sync`
- Source PR: `#1`
- Production source merge: `71f65514bd8eb0db70f7df93236d31796a4972b1`
- Previous source: `5c75c4ac9c79fbed250d8c0695e8d7c65cb7cc5f`
- Deployment UTC: `2026-07-21T01:24:42Z`
- Founder validation date (America/Los_Angeles): `2026-07-20`
- Status: `accepted_production_validated`

## Deployment evidence

- Production checkout fast-forwarded cleanly to the approved merge.
- Privacy contract passed before build.
- Docker image built successfully.
- `spinesync-web` restarted and became healthy on `127.0.0.1:8091`.
- Public homepage and `/healthz` returned successfully.
- Live JavaScript asset `/assets/index-B1Jwb_FD.js` contained the approved Umami property ID.
- Rollback image retained as `spinesync-spinesync-web:rollback-20260721T012442Z`.
- Backup retained at `/var/backups/8west-analytics-integrations/spinesync-20260721T012442Z`.

## Founder validation

Frankie validated the SpineSync property in Umami and confirmed:

- approved sanitized page paths appeared;
- patient routes collapsed to `/patients/detail`;
- imaging routes collapsed to `/imaging/viewer`;
- no patient or study identifiers appeared;
- no query strings, hashes, form values, browser-storage values, custom events, referrers, or clinical/financial data appeared;
- application navigation and demo workflows remained functional.
