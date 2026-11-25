# Fire Safety BD — Community management & moderation

## Scope
- My Posts: pending, approved, rejected. Owner-only text edit (existing photo unchanged); changed post returns to pending. Delete hides the post, does not erase records or files.
- Report other users' visible posts/comments, with fixed reason. One report per account/target, maximum 20 per day. Server derives ownership from bearer session.
- Owner can hide own comment; admin can hide comments directly, hide reported content and resolve, resolve without hiding, or dismiss reports. Admin session and CSRF protection retained. Existing comments remain visible until moderated.
- No image replacement or permanent erasure in this phase. Existing direct image URLs may remain accessible; a later retention/cleanup policy is needed. No automatic push notifications.
- Existing post/comment actions retain their existing limits.

## Deploy to staging first
1. Back up database and production PHP. Inspect actual column definitions (SHOW COLUMNS FROM community_posts; SHOW COLUMNS FROM community_comments;). Confirm status supports hidden, existing post moderated_at is nullable, and FK ID types match BIGINT UNSIGNED. If not, reconcile schema before migration; do not blindly run ALTER against live DB.
2. Run backend/migrations/20261125_community_moderation.sql after the 20261118 photo migration. Verify community_reports and unique key.
3. Compare and deploy backend/api/community/index.php to api/community/index.php and backend/community_review.php to community_review.php. Do not overwrite credentials/config/uploads. Existing .cpanel.yml does not deploy the API file or SQL; deploy those explicitly.
4. Verify health endpoint includes reports_table=true. Build signed APK after backend deploy. Keep main and live deployment unchanged until review passes.

## QA acceptance checklist
- Flutter analyze, flutter test, PHP lint; Android release build and staging integration.
- Existing create/approve/like/comment/image upload still work. Public feed excludes pending, hidden and rejected.
- My Posts shows only signed-in account's own pending/approved/rejected posts; anonymous call returns 401.
- Edit own approved text -> pending, unavailable from public feed until reapproved; image retained. Rejected post can be edited and resubmitted. Empty text allowed only if existing image; no-op preserves status.
- Confirm delete hides own post. Second account cannot edit/delete it (404), even with forged request. Owner can hide their visible comment, not someone else's.
- Report visible content from another account; own/hidden target denied. Repeat returns 409, invalid reason 422, rate limit 429, no token 401.
- Admin reports show escaped content. Resolve/dismiss and hide actions require admin + CSRF; hiding comments updates public comment count and removes comment from the list. Verify reports against removed targets are handled.
- Check two devices, expired sessions, slow network, light/dark and Bengali/English.
- Test existing account deletion and foreign-key cleanup on disposable accounts. Staging test is required; no production schema or user data accessed in implementation.
