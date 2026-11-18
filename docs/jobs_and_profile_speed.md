# Fire Safety BD — live job circulars and faster Profile navigation

## Profile navigation
- Previously, selecting Profile caused two consecutive `GET /api/auth/me.php` requests: one in `AuthGuard.ensureAuthenticated` and another in `ProfilePage.initState`. Both could block on mobile network latency.
- `AuthService.validateSession()` now reuses a successfully validated, **token-bound** session for at most **two minutes**, and coalesces concurrent requests for the same token.
- The session snapshot is cleared on logout, account deletion, new login and profile update; Profile's Refresh button and successful profile edit force a server fetch.
- When the cache expires, the app revalidates the session with the server. Server 401/403 still removes an invalid token. A stale request cannot delete a newly logged-in user's token.
- This is a navigation optimization, not offline authentication. Measure Profile tab responsiveness on a real phone with normal and slow connections.

## Job circular features
- Jobs page is no longer a list of hardcoded/example employers.
- It reads only published records from `GET /api/jobs/list.php`, and provides search (title, organization, location), government/private filters, active/expired filters, refresh, detail pages and official external application/circular links.
- Dates, salary, requirements and official links come from the database. No fake job data is displayed.
- Only absolute HTTPS links are opened in an external browser. An expired job cannot be applied to from the app.
- No account is required by the read API; Home currently still requires login to enter the Jobs page, matching the existing navigation policy.

## Required server deployment — not automatic

This repository's Codemagic workflow **only builds the Android app**. It does **not** deploy PHP files or run SQL. Complete the following on staging first, then production:

1. Back up the database. Import `backend/sql/job_circulars.sql` into the database already used by `/db.php`. The SQL creates a separate `job_circulars` table; it does not modify existing user, auth or marketplace tables.
2. Upload `backend/api/jobs/list.php` to the live server at `/api/jobs/list.php`, alongside existing `/api/auth` and `/api/marketplace` endpoints.
3. Upload `backend/admin/jobs.php` to `/admin/jobs.php`. The admin script requires the existing `/db.php` to expose a PDO instance in `$pdo`.
4. Configure the PHP server environment variable `FIRE_SAFETY_JOBS_ADMIN_PASSWORD_HASH` to a PHP `password_hash(..., PASSWORD_DEFAULT)` value. Generate the hash on a trusted server; never commit passwords, hashes or DB credentials to GitHub. Limit `/admin/jobs.php` to HTTPS, and preferably add IP allowlisting or HTTP server access controls. For proxy setups, ensure PHP receives the correct HTTPS flag from trusted server configuration; do not blindly trust client-provided proxy headers.
5. Open `https://fire.manobikishwarganj.com/admin/jobs.php`, sign in, create a real verified circular as **draft**, review it, and change status to **published**. **Archived** records disappear from the public API. Only authorized staff should receive admin access.
6. Confirm `https://fire.manobikishwarganj.com/api/jobs/list.php` returns `{"success":true,"data":[...]}` with real published circulars, and no drafts/archived records. A fresh empty database should return `{"success":true,"data":[]}`.
7. Run `php -l` on both PHP files, verify database permissions and HTTPS, and test login/CSRF rejection, invalid links, drafts, publication, expiry and archive on staging.
8. Merge the PR and run Codemagic `Fire Safety BD Android Build`; check `flutter analyze`, `flutter test test/job_circular_test.dart`, release APK signing and on-device Jobs page. `flutter pub get` resolves the new `url_launcher` dependency.

## PHP API contract
`GET /api/jobs/list.php` responds with `success` and `data` (up to 200 most recently published records). Fields: `id`, `organization`, `title`, `job_type` (`government` or `private`), `employment_type`, `location`, `salary`, `description`, `requirements`, `application_deadline` (nullable `YYYY-MM-DD`), `published_at` (ISO-style timestamp), `apply_url`, `circular_url`.

Error response is JSON with `success:false`; the app displays retry instead of dummy jobs. Public API never includes draft or archived records. For actual job applications the app only opens the employer's official HTTPS website; it does not collect CVs or promise an application was submitted.

## Security and deployment limits
- The standalone admin panel uses a password hash supplied by the server, session cookies, CSRF tokens, prepared SQL, HTML escaping, input validation and an in-session failed-login lockout. It is not integrated with the main app's user roles. Harden the admin route at the web server before production use.
- `/db.php` is intentionally **not included** here and must already exist on the server. No database credentials are stored in this repository.
- **Neither live server deployment nor device tests have been performed in this PR.** Do not describe the live job feature as working until the PHP/SQL deployment and on-device tests succeed.
