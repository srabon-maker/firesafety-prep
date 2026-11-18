# Fire Safety BD — Job Circulars (existing cPanel backend)

## Verified source
The user previously uploaded `manobiki_firesafetyjobprep.sql` (Nov 18, 2026). It **already contains** `job_circulars`, `categories` and the `fk_jobs_category` relationship. The existing table uses `application_url`, `category_id`, `vacancies` and `is_pinned`, **not** `apply_url`, `job_type` or `circular_url`. Its `published_at` may be NULL. The user's earlier dashboard package `fire_safety_bd_marketplace_auto_slug_v5.zip` already links to `job_circulars.php` and uses `admin_helpers.php` + `start_secure_session()` + `require_admin()` + `db.php`.

**Do not import the incompatible table-creation script from PR #22 or re-import the full SQL dump into a live database.** Back up production first. `backend/sql/job_circulars.sql` now contains only read-only verification queries.

## What this patch changes
- Public `api/jobs/list.php` uses the **existing** table and aliases `application_url AS apply_url` for the Flutter API; category names come from `categories`, and `is_pinned` controls ordering.
- Flutter displays real categories, vacancies and pinned status, and does not invent government/private sector labels (the uploaded SQL does not store that distinction).
- New `backend/job_circulars.php` provides the publisher page **within the existing admin login**. The original dashboard already links to this filename. No second admin password or `FIRE_SAFETY_JOBS_ADMIN_PASSWORD_HASH` is required.
- `backend/admin/jobs.php` is a backward-compatible redirect after the existing admin auth check.
- Published circulars appear in the public API; draft and archived circulars do not. New published posts receive `published_at`; old published posts with NULL dates use `created_at` for display and ordering.

## cPanel deployment (manual, not performed by GitHub)
1. Back up your live MySQL database and existing `job_circulars.php` (if present). **Do not re-import the complete SQL dump.**
2. In phpMyAdmin, select the existing `manobiki_firesafetyjobprep` database and run the **read-only** queries in `backend/sql/job_circulars.sql` to confirm the current live schema matches the previously uploaded snapshot.
3. In the subdomain document root containing `db.php`, `admin_helpers.php` and `fire_safety_job_prep_dashboard.php`, upload `backend/job_circulars.php` as `job_circulars.php` **after reviewing any existing file for features/data you want to preserve**.
4. In the same document root, upload `backend/api/jobs/list.php` to `api/jobs/list.php`. No schema migration is needed for the verified dump.
5. Optional: upload `backend/admin/jobs.php` to `admin/jobs.php` for redirects from older links. The normal dashboard link goes directly to `job_circulars.php`.
6. Test the existing dashboard login, open `/job_circulars.php`, create a draft and then publish a verified real circular. Check `https://fire.manobikishwarganj.com/api/jobs/list.php` returns `{"success":true,"data":[...]}`. No drafts should be returned.
7. Run `php -l job_circulars.php` and `php -l api/jobs/list.php` if cPanel Terminal is available; check PHP errors and verify HTTPS and `db.php` PDO connection.
8. Merge this compatibility PR, build the Flutter APK with Codemagic, run job circular widget/model tests and test the app on an Android device.

## Security and scope
- Admin authorization uses the existing `admin_helpers.php` implementation; the code assumes that `require_admin()`, `csrf_token()`, and `verify_csrf()` exist, as observed in the uploaded dashboard.
- The API is read-only, returns only published circulars and never includes passwords or private user data.
- External application links must be HTTPS. The app does not collect CVs.
- Production cPanel and database are **not directly connected to this chat**. GitHub merging does not deploy PHP to cPanel.
- The uploaded SQL dump is a snapshot, not proof of the **current** production schema. Confirm with read-only queries before deployment.

## Profile responsiveness
Profile uses a token-bound, two-minute successful-session cache to avoid repeated `me.php` requests when switching tabs. Logout, new login, profile updates and manual refresh invalidate it. Profile speed must be verified on device.
