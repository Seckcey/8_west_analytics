# 8westit.com Production Analytics Validation

## Status

Validated in production on 2026-07-20.

## Property

- hostname: `8westit.com`
- additional hostname: `www.8westit.com`
- Umami website ID: `55ff5195-9059-495e-a2fc-5a707081404d`
- source repository: `Seckcey/8westit-website`
- source merge commit: `9ee0b36862babbc33ca122f4798e1836700f8632`
- live document root: `/srv/8west/www/8westit.com/current/public`

## Validation evidence

Frankie confirmed the production canary after deployment.

Accepted behavior:

- production page view observed in the isolated 8 West IT property;
- `consultation_button_clicked` observed;
- `contact_email_clicked` observed;
- `milepost_login_clicked` observed;
- `service_link_clicked` observed;
- `blog_link_clicked` observed;
- no complete URLs, email addresses, query strings, or arbitrary link text observed in event attributes;
- public website navigation and contact behavior remained functional;
- analytics remained fail-open.

## Privacy boundary

The active integration sends automatic page views and fixed categorical events only. It does not send forms, credentials, portal data, email contents, identifiers, complete destination URLs, query strings, hashes, or free-form link text.

## Rollback

Production uses the release-directory and `current` symlink layout. Restore the previous release by switching `/srv/8west/www/8westit.com/current` back to the release path printed by the deployment command.
