# Portfolio Analytics Batch 2

## Scope

1. `coa.nexusanalyticallabs.com`
2. `nexusanalyticallabs.com`
3. `8westit.com`
4. `calc.8westbio.com`

Each hostname receives a separate Umami production property. No property IDs or dashboards are shared.

## Source and deployment mapping

### coa.nexusanalyticallabs.com

- repository: `Seckcey/coa_generator`
- application: Streamlit COA generator
- source entry: `app.py`
- live path and reverse-proxy configuration: pending server verification
- initial analytics: page view only

The workflow accepts client/company, sample/compound, lot/batch, identity, dates, purity, assay, add-on tests, notes, chromatogram files, and product images. None of those values, filenames, generated COA numbers, or PDF names may enter analytics.

### nexusanalyticallabs.com

- repository: `Seckcey/nexus_analytical_labs`
- application: Flask customer testing request app
- likely application directory from repository runbook: `/var/www/nexus_analytical_labs`
- live path, service, and Nginx configuration: pending server verification

Automatic page tracking is disabled because the payment route contains a generated request number. The integration must send only sanitized page views for `/` and `/payment`.

### 8westit.com

- repository: `Seckcey/8westit-website`
- current analytics hook: `analytics.js`
- live document root: `/srv/8west/www/8westit.com/current/public`

The dormant GA4 placeholder will be replaced with self-hosted Umami. Existing code currently derives free-form link text and full URLs; those fields are not allowed in the Umami replacement.

### calc.8westbio.com

- repository: `Seckcey/8westbio_pepcalc`
- application: React/Vite calculator
- source entry: `src/main.tsx`
- interaction logic: `src/App.tsx`
- live document root: `/srv/8west/www/calc.8westbio.com/current/public`

No numeric input, calculation output, syringe selection, copied result text, or locally saved preset value may enter analytics.

## Deployment order

1. Create and record all four Umami website IDs.
2. Verify Nexus live service and reverse-proxy paths.
3. Implement `8westit.com` and `calc.8westbio.com` repository changes.
4. Implement sanitized manual tracking for `nexusanalyticallabs.com`.
5. Add page-view-only tracking to the COA generator using the least invasive supported integration for its live Streamlit deployment.
6. Deploy one property at a time and validate Realtime before continuing.

## Common acceptance checks

- production-only domain allowlist;
- search parameters and hashes excluded;
- analytics outage does not affect application behavior;
- no session replay, heatmaps, form capture, or identifying data;
- exact form/calculator/COA values absent from analytics requests;
- one property cannot receive another property's events;
- rollback is documented before activation.
