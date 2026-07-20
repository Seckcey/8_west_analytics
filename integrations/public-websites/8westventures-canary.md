# 8westventures.com Public Website Canary

## Status

Approved for implementation. The Umami production property and live Apache deployment path are verified.

## Verified deployment facts

- Umami website ID: `508def7a-17a5-4510-a49b-a90c0cdafe76`
- Tracker URL: `https://analytics.8westventures.com/script.js`
- Production hostnames: `8westventures.com`, `www.8westventures.com`
- Apache document root: `/srv/8west/www/8westventures.com/current/public`
- Current release: `/srv/8west/www/8westventures.com/releases/hostgator-20260717T121624Z/public`
- Source repository: `Seckcey/8west_hostgator_account_all`
- Source paths:
  - `public_html/index.html`
  - `public_html/assets/js/main.js`

The source contains a single-page corporate website, same-page navigation, links to the employee intranet and 8 West IT, direct email links, and a Web3Forms contact form.

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

## Implementation design

1. Load the Umami tracker asynchronously from the site's existing `assets/js/main.js`.
2. Set the website ID and restrict tracking to the two production hostnames.
3. Exclude search parameters and hash fragments.
4. Use a single guarded click classifier with hard-coded categorical values for approved links.
5. Fire `contact_form_started` once on the first genuine interaction with a non-honeypot field.
6. Fire `contact_form_submitted` only after Web3Forms returns success.
7. Fire `contact_form_failed` with only `provider_rejected` or `network_error`.
8. Guard and queue manual tracking calls so an unavailable or blocked analytics script cannot affect site behavior.

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
- removal requires only reverting the `main.js` analytics block.

## Rollback

Restore the prior `assets/js/main.js` from the current release or switch the `current` symlink back to the prior release. No application database, Apache, Caddy, or Umami server rollback is required.
