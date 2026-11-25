# Dynamic homepage rollout

Apply backend/migrations/20261125_dynamic_homepage.sql after backup, then deploy reviewed main via cPanel. The migration only creates two new tables. Do not overwrite db.php, uploads, signing credentials or package identity.

Admin: /homepage_admin.php (requires existing admin login and CSRF). Enter banner/tip/interview draft, publish explicitly. Reorder/hide optional sections via comma-separated keys. Core quick links and bottom navigation are not remotely removable. Image URLs refer to existing first-party uploads; no new uploader. Public API /api/homepage/index.php exposes published content only, plus published question category counts. No authenticated answers or personal stats are exposed by this API. Interviews have role and industry filters, difficulty label, optional English question/answer and expandable answers. No AI interviewer, voice recording, bookmark persistence or interview scoring yet.

Test logged-out access to admin (must redirect), draft exclusion, publication, section ordering, invalid URL rejection, interview search and paging, and old endpoints. Flutter search is a destination picker for jobs, notes, question category and interview search (not full cross-module ranked search). Existing model-test practice and dashboard are reused; no fake numbers. Build with the existing Codemagic signed Android workflow only after CI. Test navigation auth gates, refresh/offline state, English/dark mode, and small screens. No change to signing or app version.

A later phase is required for full question search, topic taxonomy, non-MCQ questions, unread home badge, direct homepage personal stats, live community/market product previews, interview bookmarks and mock interview.
