# NaildiT analytics production acceptance

- Property: `naildit.8westventures.com`
- Umami property ID: `ea32b4fe-d902-4a69-a7a1-ede08162485b`
- Source repository: `Seckcey/naildit`
- Source PR: `#1`
- Production source merge: `5834015e7f94356ae12df460208d17c17be7fa6b`
- CI artifact source: `5c2fecd5f7844a558a329b3fd9cb92494db96c56`
- CI artifact ID: `8479745185`
- CI artifact SHA-256: `b5b04868d3c2aa81dbd0b3eb78593c52f23cd57fcf46576df1846d6f9edc828d`
- Deployment UTC: `2026-07-21T02:56:42Z`
- Founder validation date: `2026-07-20` America/Los_Angeles
- Status: `accepted_production_validated`

## Deployment evidence

- The build artifact was transferred directly to the production server and its outer checksum matched the approved workflow record.
- Archive integrity, exact contents, source marker, and internal checksums passed.
- The isolated candidate matched the verified artifact byte-for-byte and served successfully before activation.
- Production activation used an atomic directory swap with automatic rollback protection.
- Public homepage, API health, frontend service, backend service, and central analytics script passed after activation.
- Live JavaScript asset `/assets/index-B2vshX9H.js` contained the approved property ID and tracker URL.
- Rollback retained at `/opt/naildit/frontend/dist.rollback-20260721T025642Z`.
- Backup retained at `/var/backups/8west-analytics-integrations/naildit-20260721T025642Z`.

## Founder validation

Frankie validated the NaildiT property in Umami. The approved sanitized page path `/` appeared, no disallowed analytics payloads or custom events appeared, and the application remained functional.
