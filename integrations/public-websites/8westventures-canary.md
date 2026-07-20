# 8westventures.com Public Website Canary

## Status

Approved for implementation planning. Production instrumentation remains blocked until the Umami property ID is recorded and the exact deployment path is verified.

## Source inspection

The current source is represented in `Seckcey/8west_hostgator_account_all` under `public_html/`:

- `public_html/index.html`
- `public_html/assets/js/main.js`

The source contains a single-page corporate website, same-page navigation, links to the employee intranet and 8 West IT, direct email links, and a Web3Forms contact form.

The live deployment path on the current EC2 host must be verified before changing production files.

## Tracking scope

Automatic page views are allowed only for `8westventures.com` and `www.8westventures.com`. URL search parameters and hashes must be excluded.

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

## Implementation design

1. Add the deferred Umami tracker to the document head using the production property ID.
2. Restrict tracking with `data-domains="8westventures.com,www.8westventures.com"`.
3. Add `data-exclude-search="true"` and `data-exclude-hash="true"`.
4. Add static `data-umami-event` attributes for navigation and outbound links where possible.
5. Use JavaScript only for contact-form lifecycle events.
6. Fire `contact_form_started` once on the first genuine interaction with a non-honeypot field.
7. Fire `contact_form_submitted` only after Web3Forms returns success.
8. Fire `contact_form_failed` with only `provider_rejected` or `network_error`.
9. Guard every manual tracking call so an unavailable or blocked analytics script cannot affect site behavior.

## Acceptance checks

- site works with the analytics host blocked;
- tracker loads asynchronously;
- page views appear only in the production property;
- no search parameters or hashes appear in tracked paths;
- every approved click fires once;
- form start fires once per page load;
- successful form submission fires only after provider confirmation;
- failures contain only `provider_rejected` or `network_error`;
- browser network inspection shows no form contents or identifying values sent to Umami;
- removal requires only deleting the tracker tag and approved event hooks.

## Rollback

Remove the Umami tracker tag and all `data-umami-event*` attributes, then remove the guarded contact-form tracking calls. No application database or server configuration rollback is required.
