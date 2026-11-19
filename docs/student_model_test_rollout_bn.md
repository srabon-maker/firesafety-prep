# Student Model Test System — rollout

This release connects the Flutter Model Test screen to server-managed exams.

## Database migration
1. Back up the production database.
2. Select the same database used by `backend/db.php` in phpMyAdmin.
3. Run `backend/migrations/20261119_student_model_test_attempts.sql` once.
4. Verify both tables exist: `model_test_attempts` and `model_test_attempt_questions`.

The migration adds new tables only; it does not alter existing user, question, or model-test rows.

## Deploy files
Deploy together:
- `backend/api/tests.php` to `public_html/api/tests.php`
- `backend/migrations/20261119_student_model_test_attempts.sql` is SQL-only; do not upload as executable PHP
- `backend/model_tests.php` to the existing admin page
- Flutter changes are included in the next app build, not cPanel PHP deployment.

## Behavior
- Published tests within their schedule are listed in the app.
- Starting an exam creates an attempt and immutable question/answer snapshots.
- Answer selections are sent to the server immediately.
- The server owns the expiry timestamp and calculates the final score.
- Correct answers and explanations are returned only after submission.
- A test with attempts/results cannot be hard-deleted in Admin; archive it instead.

## Important current limits
- A user can create a new attempt after a previous attempt is submitted; attempt limits are not configured yet.
- Results are visible immediately after submission; per-test result-release controls are not implemented yet.
- App timer submits when the local countdown reaches zero; server rejects answers after its own expiry timestamp.
- Push notifications, proctoring, tab/app switching detection, and server-driven forced submission while the app is closed are not included.
