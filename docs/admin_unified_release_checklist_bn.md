# Fire Safety BD — Unified Admin UI release checklist

## Scope
Presentation-only work on the PHP Admin Panel. All SQL, authentication, CSRF checks, POST handling, and API behavior must remain unchanged. Do not deploy this whole branch to production without checking each live file against its repository counterpart.

## Shared visuals
- `backend/assets/admin-unified.css`: shared maroon/orange color, cards, form and sidebar refinements.
- Sidebar navigation unified for Question Bank, Model Tests, Categories, Job Circulars.
- Shared admin sidebar shell for Notes, standalone Marketplace, Community Review, Job Submission Review.
- Users page retains its mobile cards and original Fire Safety BD logo.
- Existing Model Test intra-page section shortcuts remain available.

## Code/source mapping
| Source | cPanel document root target | Notes |
| --- | --- | --- |
| `backend/admin/fire_safety_job_prep_dashboard.php` | `fire_safety_job_prep_dashboard.php` | Baseline compared with uploaded live copy (only Users link and final newline differed at comparison time). |
| `backend/users.php` | `users.php` | Already live as of 18 November 2026. |
| `backend/questions.php` | `questions.php` | Confirm current live version before replacing. |
| `backend/model_tests.php` | `model_tests.php` | Confirm current live version before replacing. |
| `backend/notes.php` | `notes.php` | Confirm current live version before replacing. |
| `backend/category_management.php` | `category_management.php` | Source from verified cPanel upload, shared UI only. |
| `backend/job_circulars.php` | `job_circulars.php` | Source from newer 523-line cPanel upload; preserves extra parsing functionality. |
| `backend/marketplace_admin.php` | `marketplace_admin.php` | Confirm current live version before replacing. |
| `backend/community_review.php` | `community_review.php` | Confirm current live version before replacing. |
| `backend/job_submission_review.php` | `job_submission_review.php` | CURRENT REPO VERSION DIFFERS FROM LIVE; reconcile first. |
| `backend/assets/admin-unified.css` | `assets/admin-unified.css` | Required for shared theme. |

## Before release
1. Keep the existing complete backup outside the web root. Back up the database separately.
2. Compare each production PHP file against the GitHub candidate. Preserve live-only functionality.
3. Run `php -l` on every changed PHP file using the target server PHP version.
4. Review screenshots at mobile and desktop widths; verify all sidebar links, active states, card/table overflow, and search.
5. Test admin sign-in/out, question CRUD/import, notes CRUD, model test operations, job circular parsing/CRUD, marketplace workflows, category CRUD, community moderation, job submissions, and user search.
6. Only after review update `.cpanel.yml` with an explicit allowlist and backup-per-release. Current `.cpanel.yml` still deploys only Users and Dashboard, **not** this whole UI release.
7. Never copy `db.php`, `config.php`, `.env`, uploads, logs, SQL dumps, keys, or session secrets from Git.

## Important existing menu placeholders
Dashboard currently routes Notifications and Settings to `questions.php`. These are not independent implemented pages in the verified repository; do not silently claim they were redesigned or change their behavior as part of a visual-only release.
