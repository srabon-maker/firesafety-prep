# Fire Safety BD — Admin Panel source

The live cPanel dashboard source will be added here after confirming the current deployed version and screening for credentials.

**Expected initial file:** `fire_safety_job_prep_dashboard.php` → cPanel document root `fire_safety_job_prep_dashboard.php`.

Other existing admin PHP pages are already tracked in the parent `backend/` directory, including `community_review.php` and `job_circulars.php`.

Never commit `db.php`, production credentials, SQL dumps containing user data, signing keys, or uploaded user files. Do not assume a GitHub merge deploys the live site. See `docs/admin_panel_git_workflow_bn.md`.
