# Fire Safety BD — Admin Panel source

The working cPanel dashboard source is now tracked in this folder, based on the latest working community dashboard version (Nov 18, 2026). Verify against the live file before deploying any later changes.

**Tracked dashboard:** `fire_safety_job_prep_dashboard.php` → cPanel document root `fire_safety_job_prep_dashboard.php`.

Other existing admin PHP pages are already tracked in the parent `backend/` directory, including `community_review.php` and `job_circulars.php`.

Never commit `db.php`, production credentials, SQL dumps containing user data, signing keys, or uploaded user files. Do not assume a GitHub merge deploys the live site. See `docs/admin_panel_git_workflow_bn.md`.
