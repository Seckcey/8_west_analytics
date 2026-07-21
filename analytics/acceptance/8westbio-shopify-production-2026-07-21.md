# 8 West Bio Shopify analytics production acceptance

- Property: `8westbio.com`
- Platform: `Shopify`
- Shopify plan: `Basic`
- Umami property ID: `bba152c1-679e-4c00-8807-c9c64de603fc`
- Published theme: `8 West Bio - Umami Preview`
- Published theme ID: `gid://shopify/OnlineStoreTheme/156216721598`
- Previous live theme retained for rollback: `Drive`
- Previous theme ID: `gid://shopify/OnlineStoreTheme/154266304702`
- Production validation date (America/Los_Angeles): `2026-07-21`
- Status: `accepted_production_validated`

## Production evidence

- Shopify reported the validated theme as role `MAIN`, with processing complete and no processing failure.
- `layout/theme.liquid` contains the deferred `8west-umami.js` storefront hook.
- Production `layout/theme.liquid` MD5: `6c776dbe8a04900970c00a4a0092c6ec`.
- Production `assets/8west-umami.js` MD5: `46effbc0826c9522eff038f750b4ba2e`.
- Production `assets/8west-umami.js` size: `947` bytes.
- The former live `Drive` theme remains unpublished and available as the rollback copy.
- Browser validation confirmed the storefront asset and Umami tracker loaded successfully, CORS preflight returned `204`, and analytics delivery returned `200`.

## Privacy contract

- Sanitized storefront pageviews only.
- Session replay, form capture, free-form events, customer identifiers, cart contents, checkout data, order data, prices, product handles, collection handles, search terms, query strings, hashes, and full referrer URLs are prohibited.
- Account, checkout, order, password, challenge, and search routes are excluded.
- Product, collection, page, and blog detail routes are collapsed to fixed labels such as `/products/detail`, `/collections/detail`, `/pages/detail`, and `/blogs/detail`.
- Umami automatic tracking is disabled; manual pageviews send only the approved property ID and fixed path label.

## Founder validation

Frankie validated the live 8 West Bio Shopify storefront and confirmed that the production Umami property received sanitized pageviews, the storefront remained functional, and no prohibited customer, product-handle, cart, checkout, order, query, hash, price, or other sensitive payloads appeared.