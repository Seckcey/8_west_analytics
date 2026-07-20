# Nexus Analytical Labs Request Site Analytics Acceptance

- Hostname: `nexusanalyticallabs.com`
- Additional hostname: `www.nexusanalyticallabs.com`
- Umami property ID: `28a7129d-766b-4c54-a979-9a234e6be68d`
- Integration repository: `Seckcey/nexus_analytical_labs`
- Integration merge commit: `adad4c65862f7238026ace2eb97f35a90da795b4`
- Production service: `nexus-analytical-labs.service`
- Public upstream: `172.17.0.1:8010`
- Production backup: `/var/backups/8west-analytics-integrations/nexus-request-20260720T200016Z`
- Validation date: 2026-07-20
- Result: passed

## Deployment evidence

- Correct production repository and WSGI entrypoint verified.
- Existing tracked production drift preserved before deployment.
- Approved analytics files extracted directly from the merged Git objects without pulling, resetting, or overwriting unrelated production files.
- HTML-only analytics injection passed.
- Production WSGI import passed.
- Service, listener, and direct upstream HTTP readiness passed.
- Public apex and `www` hostnames passed.
- Health endpoint remained outside the HTML analytics injection boundary.

## Observed analytics behavior

- Sanitized page paths only: `/`, `/payment`, `/other`.
- Approved events only:
  - `testing_request_started`
  - `testing_request_submit_attempted`
  - `payment_proof_email_clicked`
- No request number, customer name, company, email address, phone number, compound, lot or batch, quantity, intended use, notes, selected tests, total, wallet information, payment-proof contents, exact payment URL, referrer, or free-form event data observed.
- User confirmed the production property as validated.

## Production delta

Expected analytics-only worktree delta:

- modified: `wsgi.py`
- added: `analytics_integration.py`
- added: `static/js/analytics.js`
