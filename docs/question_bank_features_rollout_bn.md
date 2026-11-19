# Question Bank feature migration (2026-11-19)

This release adds question archive/restore, image attachments and revision history. The PHP code keeps existing Add/Edit and import behavior working before this migration; the new features remain disabled until the migration is applied.

## Safe rollout

1. Take a fresh database backup in cPanel/phpMyAdmin.
2. Open the database used by the live Fire Safety BD backend.
3. Run backend/migrations/20261119_question_bank_features.sql exactly once.
4. Confirm that questions.image_path, questions.is_archived, and question_revisions exist.
5. Deploy the reviewed GitHub PR through cPanel Git Version Control.
6. Verify Question Bank, bulk actions, archive/restore, preview, image upload, revision history and model-test selection.

The migration does not rewrite or delete existing question rows. Existing rows receive is_archived=0 by the column default and image_path=NULL.

## Feature notes

- Bulk actions are limited to 200 selected IDs per request and use the existing admin CSRF protection.
- Question images accept JPEG, PNG and WebP up to 5 MB; the upload directory is created on first upload and gets a PHP execution-deny .htaccess.
- Usage count is read from existing model_test_questions links; no usage data is duplicated.
- Archived questions are excluded from new random/manual model-test selection. Existing model-test links are not removed.
- Revision snapshots are stored in question_revisions; hard-deleted question records keep their revision history because the migration intentionally adds no cascading foreign key.
- Explanation was already part of the existing question form and remains supported; it is also shown in the question preview and revision snapshots.

Do not run the ALTER TABLE section a second time. If the migration has already been applied, skip it and verify the columns/table instead.
