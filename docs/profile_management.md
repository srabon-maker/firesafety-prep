# Fire Safety BD — Profile editing and account deletion

## App behavior

- Profile header shows avatar, name and email.
- Tap the profile summary card to open the standalone Personal information page; the eight fields and Edit information action are no longer shown in an expandable card on the main profile.
- **Edit profile** opens a form for name, phone, employment status, company, designation, workplace and address. Google email is read-only.
- **Delete account** requires the user to type `DELETE`. It never deletes anything on opening the dialog. It only clears the local session after a verified server response `{"success":true,"deleted":true}`.
- On failed API calls, the app shows an error and does not claim the update or deletion succeeded.

## Server deployment (required)

This repository does not deploy the existing production PHP backend automatically. **Do not test deletion against production users.** After staging verification, manually upload the following files from this branch:

| Repository file | Server destination |
|---|---|
| `backend/api/auth/profile_common.php` | `/api/auth/profile_common.php` |
| `backend/api/auth/update_profile.php` | `/api/auth/update_profile.php` |
| `backend/api/auth/delete_account.php` | `/api/auth/delete_account.php` |

The files expect the existing `/db.php` PDO connection, `users` and `auth_sessions` tables, and marketplace tables from the supplied database schema. No database passwords belong in GitHub.

### Endpoint contracts

- `POST /api/auth/update_profile.php` — `Authorization: Bearer <session_token>`, JSON body with `full_name`, `mobile_number`, `current_status`, `company_name`, `designation`, `job_location`, `current_address`. Responds `{"success":true}` only after the database update. The server derives the user ID from the session; email and Google ID are never editable.
- `POST /api/auth/delete_account.php` — same Bearer authorization, JSON `{"confirmation":"DELETE_MY_ACCOUNT"}`. On successful transaction, responds `{"success":true,"deleted":true}`.
- Invalid or expired sessions return 401; validation failures return 422; accounts with active orders or service requests return 409.

### Important deletion policy

The supplied SQL schema uses restrictive foreign keys on `market_orders.user_id` and `market_service_requests.user_id`. The implementation **blocks deletion while orders are pending/confirmed/processing/shipped or service requests are pending/reviewing/approved**. Otherwise, it deletes the account's orders and service requests, then deletes the user, relying on existing ON DELETE CASCADE rules for related sessions, cart, posts/comments, test attempts and notifications.

**Business/data retention review required before deploying**: this implementation permanently removes completed order and service history. If transaction records must be retained for tax, consumer protection, dispute resolution or accounting, change the backend deletion strategy and schema to retain legally required records without identifiable profile data. Back up the database and test rollback/cascades in staging first.

### Validation checklist

1. Upload all three PHP files to a staging backend with a matching database schema; confirm `php -l` succeeds for each.
2. Update a test account and verify `me.php` returns the changed fields; confirm the email and Google ID are unchanged.
3. Verify unauthenticated requests fail (401), invalid fields fail (422), and deleting with wrong confirmation fails (422).
4. Verify an account with active orders cannot be deleted (409) and retains its session.
5. Verify deletion of a disposable test account removes its sessions and user-owned records; `me.php` rejects the old token afterward.
6. Build the Flutter feature branch in Codemagic; inspect the standalone personal information page, edit form, error handling and delete confirmation in both Light and Dark modes.

**Not yet deployed or tested against a live server.** The PR must remain draft until server and mobile tests pass.
