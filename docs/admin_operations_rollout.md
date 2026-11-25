# Admin operations — initial rollout

## Scope
One authenticated admin page with Analytics, Notifications and Settings tabs. The dashboard links to all three. Existing admin session and CSRF helpers are reused. No credentials or user data are included.
- Publish a database inbox record for one registered user or a registered audience selected by current_status. Broadcast disabled initially, default cap 500, configurable 1–5000. Transaction, unique request key and confirmation protect against partial/duplicate submissions. History records original recipients and current read flags. No push, schedule, app inbox or preference sync is included.
- Persist broadcast enable/limit and default analytics period. No global mobile app maintenance switch, auth configuration, or payment setting is changed.
- Read-only 7/30/90 calendar day analytics: registrations, published jobs, submitted model tests, practice, community, orders, paid delivered order value, services, notifications. Daily trends and status breakdowns. Database timezone; orders are grouped by creation date and current status, not cash flow. Missing tables are unavailable, never silently zero. No app activity/retention instrumentation.

## Deploy
1. Back up DB and PHP. Confirm users.id BIGINT UNSIGNED, users.is_registered/current_status, notifications fields and InnoDB. Apply backend/migrations/20261125_admin_operations.sql in staging; verify singleton id=1 and unique request_key. No existing table changes.
2. Deploy backend/admin_operations.php to web root and updated dashboard. .cpanel.yml includes both; existing Marketplace deployment remains. No automatic SQL.
3. Test unauthorized redirect, CSRF denial, invalid fields, missing migration, single recipient, duplicate submission, zero recipients, disabled broadcast, over-cap rollback, audience selection, settings persistence, HTML escaping and analytics with known records. Test one disposable user before enabling broadcasts.
4. Real app notification display/push integration and preference enforcement are separate follow-up work. Keep broadcasts disabled until policy and app behavior are validated.
5. Keep migration tables on rollback; restore admin PHP/dashboard from backup. Do not delete user notifications or campaign history without review.

Live DB and browser integration tests are not yet performed. This draft is not production-ready until staging verification.
