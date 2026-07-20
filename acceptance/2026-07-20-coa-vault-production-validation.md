# COA Vault analytics production validation

- Date: 2026-07-20
- Property: `coa.nexusanalyticallabs.com`
- Umami property ID: `2f40bcd3-42a3-4ae7-84d0-94d3aa7c0eef`
- Integration repository: `Seckcey/coa_generator`
- Integration merge commit: `9dab9d9990a42d86f3d6c2e1f82166b4446a611f`
- Live application directory: `/var/www/coa.nexusanalytical.com/public_html`
- Public service: `nexus-coa-generator.service`
- Public upstream: `172.17.0.1:8000`
- Backup: `/var/backups/8west-analytics-integrations/coa-20260720T194232Z`
- Result: **passed**

## Deployment evidence

- Production WSGI imported successfully.
- Public Gunicorn service restarted and remained active.
- Gunicorn listened on `172.17.0.1:8000`.
- Direct upstream `/login` returned HTTP 200.
- Public HTTPS `/login` returned HTTP 200.
- Analytics loader was injected into HTML responses.
- Tracker JavaScript was served with the approved property ID.
- Non-HTML injection boundary remained intact.
- Existing production application drift was preserved; no pull, reset, checkout, or overwrite of dirty application files occurred.

## Browser acceptance evidence

- Umami Realtime received production pageviews.
- Realtime screenshot showed 5 views and 3 anonymous visitors/sessions.
- Custom events remained at 0, as required for the initial COA rollout.
- Approved sanitized paths worked for accessible routes.
- `/admin/orders` returned HTTP 403 for the tested non-admin account; this is an application authorization result and not an analytics failure.
- No raw order UUIDs, COA numbers, customer/sample details, payment references, Bitcoin addresses, transaction IDs, query strings, referrers, or exact private URLs were observed.
- Login and accessible COA workflows remained functional.

## Approved analytics behavior

Pageviews only, using these sanitized paths:

- `/`
- `/login`
- `/register`
- `/account`
- `/admin/orders`
- `/order/payment`
- `/other`

Custom events, form capture, session identification, referrer transmission, and session replay remain prohibited.
