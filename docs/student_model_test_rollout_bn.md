# Student Model Test System — rollout

This release connects the Flutter Model Test screen to server-managed exams.

## Database migration
1. Back up the production database.
2. Select the same database used by `backend/db.php` in phpMyAdmin.
3. Run `backend/migrations/20261119_student_model_test_attempts.sql` once.
4. Run `backend/migrations/20261119_model_test_policies.sql` once after the attempts migration.
5. Verify both attempt tables exist and `model_tests` contains `max_attempts` and `results_released`.

The attempts migration creates two new tables. The policy migration adds two settings columns to `model_tests`; existing tests keep safe defaults (unlimited attempts and immediate result release). Neither migration rewrites existing users, questions, or saved test-question relationships.

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
- Correct answers and explanations are returned only after submission and Admin result release.
- Admin can review student attempts, scores and question-by-question answers in Model Test Admin.
- Admin can hold/release results per test and configure a maximum number of attempts per student (0 means unlimited).
- A test with attempts/results cannot be hard-deleted in Admin; archive it instead.

## Important current limits
- Attempt limits count all attempts, including submitted/expired attempts. Set 0 for unlimited attempts.
- Results release is configured per test. Existing tests default to immediate release after migration.
- App timer submits when the local countdown reaches zero; server rejects answers after its own expiry timestamp.
- Push notifications, proctoring, tab/app switching detection, and server-driven forced submission while the app is closed are not included.
