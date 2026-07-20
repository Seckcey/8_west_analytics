# 8westventures.com Public Website Canary

## Status

Production canary active and validated on July 20, 2026.

## Verified deployment facts

- Umami website ID: `508def7a-17a5-4510-a49b-a90c0cdafe76`
- Tracker URL: `https://analytics.8westventures.com/script.js`
- Production hostnames: `8westventures.com`, `www.8westventures.com`
- Apache document root: `/srv/8west/www/8westventures.com/current/public`
- Prior baseline release: `/srv/8west/www/8westventures.com/releases/hostgator-20260717T121624Z`
- Active release naming pattern: `/srv/8west/www/8westventures.com/releases/analytics-canary-*`
- Exact active release timestamp was not captured in this acceptance record.
- Source repository: `Seckcey/8west_hostgator_account_all`
- Integration commit: `ee70e2c098b004414b5018248f6bace86ffc295b`
- Integration merge commit: `173240d672b876fd813b98073fce973d1669fb7b`
- Analytics governance merge commit: `75938ec0147720d9f71b509d2aac7ee189f1a2e6`
- Deployment-layout fix merge commit: `5e680f256f13af4e526ebc5860a1966d0f3b3115`

## Tracking scope

Automatic page views are allowed only for `8westventures.com` and `www.8westventures.com`. URL search parameters and hashes are excluded.

Approved custom events:

- `navigation_clicked`
- `consultation_button_clicked`
- `portfolio_link_clicked`
- `intranet_link_clicked`
- `contact_email_clicked`
- `contact_form_started`
- `contact_form_submitted`
- `contact_form_failed`

## Privacy controls

Do not transmit:

- name, email, company, or message values;
- Web3Forms access keys or response bodies;
- complete destination URLs;
- query strings or hashes;
- IP addresses as custom event data;
- any session, customer, or production record identifier.

Only categorical values declared in `analytics/event-dictionary.yaml` may be attached.

## Implemented design

1. The site loads the Umami tracker asynchronously from its existing `assets/js/main.js`.
2. Tracking is restricted to the two production hostnames.
3. Search parameters and hash fragments are excluded.
4. A guarded click classifier emits only approved categorical values.
5. `contact_form_started` fires once on the first genuine interaction with a non-honeypot field.
6. `contact_form_submitted` fires only after Web3Forms returns success.
7. `contact_form_failed` uses only `provider_rejected` or `network_error`.
8. Manual tracking calls are guarded and queued so an unavailable or blocked analytics script cannot affect site behavior.

## Acceptance result

Frankie completed the browser acceptance test and confirmed the canary validated on July 20, 2026.

Accepted evidence:

- production page views appeared in the correct Umami property;
- approved custom events appeared;
- `contact_form_started` fired once;
- browser network inspection showed no name, email, company, message, form content, query string, hash, or identifying value in analytics requests;
- website navigation and contact-form behavior remained functional;
- analytics remained fail-open.

## Rollback

Switch `/srv/8west/www/8westventures.com/current` back to the prior baseline release or restore the prior `assets/js/main.js`. No application database, Apache, Caddy, DNS, or Umami server rollback is required.
