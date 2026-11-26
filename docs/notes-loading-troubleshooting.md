# Study notes loading troubleshooting

The reported Home preview error does not identify its cause. This branch adds bounded GET retries for transient network/gateway failures, session isolation, safe error codes, an independent Home retry, and a lightweight Home list request (supported by the updated PHP API). No premium entitlement fallback, new signing identity, or database change.

## Production verification (operator with cPanel access)
1. Request https://fire.manobikishwarganj.com/api/notes.php?page=1&premium_preview=1&summary_only=1 from a browser. Expected: HTTP 200 JSON, success true, data list, categories list, pagination object. If the earlier PHP version is installed it may ignore summary_only.
2. If HTTP 500, inspect cPanel Errors / PHP error_log for "Notes API failed:" at the request time. Do not share credentials, bearer tokens, or private note contents.
3. Check the database selected by db.php (never commit db.php). Confirm premium_memberships, premium_access_policy (row id=1), premium_note_items and premium_note_pdfs exist; verify notes/categories schema and the deployed premium_access.php / premium_learning.php files. Use the migration order in docs/premium_learning_rollout.md after backup if anything is missing. Do not reset an existing policy to free or bypass access checks.
4. After approved deployment and passing tests, verify anonymous previews, authenticated free and active premium list/detail, private PDF and search filtering. Check both the Home and Study Notes page.

HTTP_500 indicates a server-side error requiring logs/deployment or database repair; NETWORK/TIMEOUT indicate transport issues; HTTP_401/403 indicate login/access; INVALID_RESPONSE indicates non-JSON or unexpected response. This source change alone cannot establish or repair unknown production failures.
