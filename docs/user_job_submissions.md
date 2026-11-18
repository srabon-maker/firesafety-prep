# Fire Safety BD — User Job Circular Submission & Admin Approval

## Implemented behavior
- Anyone can view published jobs without login.
- Logged-in users can submit a job circular with mandatory title, organization,
  description, mobile and WhatsApp numbers. Other fields are optional.
- Contact numbers are private to admins unless a separate unchecked consent
  checkbox explicitly allows them to appear on the published job details.
- Every submission starts as Pending. Users can see their own status history.
- Admin can Approve or Reject. Approval inserts into the existing job_circulars
  table inside a transaction. Rejection does not publish the job.
- Approved jobs appear in the same Jobs API and Flutter app.
- Basic rate limit: 3 submissions per account per 24 hours.

## cPanel deployment order
Back up the existing database and PHP files; test on staging first.

1. Import backend/migrations/20261118_job_submissions.sql in phpMyAdmin.
2. Upload the new files to these document-root paths:
   - backend/api/jobs/submission_common.php -> /api/jobs/submission_common.php
   - backend/api/jobs/submit.php -> /api/jobs/submit.php
   - backend/api/jobs/my_submissions.php -> /api/jobs/my_submissions.php
   - backend/job_submission_review.php -> /job_submission_review.php
3. After SQL import, replace /api/jobs/list.php with
   backend/api/jobs/list.php, keeping a backup of the old one.
4. Admin moderation URL: /job_submission_review.php (dashboard admin login).
5. The live /job_circulars.php may be newer than the GitHub version.
   Keep the live parser/admin page and add a link to the moderation page
   manually; do not replace it with the older GitHub file.
6. PR #26 has already been merged into the PR #25 feature branch.
   Validate PR #25 and merge it into main only after checks pass.
   Build the APK from the updated main branch.

## Endpoints
- POST /api/jobs/submit.php: Bearer session + JSON -> pending ID.
- GET /api/jobs/my_submissions.php: Bearer session -> own status history.
- GET /api/jobs/list.php: public -> published jobs + consented contacts.
- /job_submission_review.php: admin session + CSRF -> Approve/Reject.

## Safety and verification
- User-supplied mobile/WhatsApp numbers are not OTP verified. Admin should
  verify employer identity and contact ownership before publishing.
- Consider reporting/takedown and OTP verification before public rollout.
- Protect personal data and backups. Define retention and deletion rules.
- No attachment uploads, pending-edit workflow, or push notifications yet.
- The new list.php REQUIRES the migration table. Deploy SQL first.
- Verify unauthenticated submission => 401, bad input => 422,
  4th submission in 24 hours => 429.
- Verify pending/rejected are absent from public API and approved is present.
- Verify contact numbers only appear with explicit user consent.
- Run php -l, flutter analyze, flutter test, flutter build apk --release.
- Verify existing published job ID 2 still loads.

NOT deployed to live cPanel and NOT tested against the production database.
