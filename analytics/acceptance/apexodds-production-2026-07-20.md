# ApexOdds analytics production acceptance

- Property: `apexodds.8westventures.com`
- Umami property ID: `d1f9c3cd-1115-4037-a679-cea8bf9bd09c`
- Source repository: `Seckcey/kalshi_bet`
- Source PR: `#13`
- Production source merge: `2fad7675cb8d07f0590dc1edb432f471913f5680`
- Previous production source: `3b538874947a617f3ea94008fab3ed8f5e9d2083`
- Active production image: `sha256:21c486ce118ffc58cf90fc528bb37283caba6b62c5b4cddfa430cdc24f433555`
- Deployment UTC: `2026-07-21T05:07:11Z`
- Founder validation date (America/Los_Angeles): `2026-07-20`
- Status: `accepted_production_validated`

## Deployment evidence

- Read-only preflight confirmed the correct EC2 host, clean `main` checkout, exact approved remote SHA, healthy Docker Compose services, healthy local and public endpoints, and that analytics was not already live.
- A rollback image, Git source bundle, and local snapshot of `.env`, `data/`, and `secrets/` were created before activation.
- The approved source was built into an isolated candidate image and tested on loopback port `18787` before production activation.
- Candidate health, login-page injection, Umami property ID, manual pageview mode, query exclusion, and hash exclusion all passed before activation.
- Production activation recreated only `apexodds-ui` and `apexodds-paper-learn`; Caddy and its certificate volumes were preserved.
- Local health, public health, public login, and public analytics JavaScript passed after activation.
- `.env` and secret-file hashes were unchanged across deployment.
- The active image ID matched the validated candidate image.
- Rollback image retained as `apexodds:rollback-20260721T050711Z`.
- Backup retained at `/var/backups/8west-analytics-integrations/apexodds-20260721T050711Z`.

## Founder validation

Frankie validated the ApexOdds property in Umami and confirmed that approved fixed page labels appeared, no email addresses, user IDs, market codes, query strings, reset tokens, balances, positions, financial values, custom events, or other disallowed analytics payloads appeared, and the application remained functional.
