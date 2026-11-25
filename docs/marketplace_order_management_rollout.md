# Marketplace order management — rollout

Builds on cPanel source imported in PR #129. Live DB schema and production credentials were not provided. Draft until checks and staging QA pass.

## Behavior
- GET orders.php?order_id=ID returns only the authenticated owner's order, snapshot line prices, delivery contact, totals, events and server-computed can_cancel. History GET remains backward compatible.
- Admin-configured flat BDT charge per nonempty cart. Default zero. Cart quotes subtotal, fee and total; checkout recalculates stock and money in a transaction and compares expected_total (never trusts client price). Old apps without expected_total can order only while fee is zero.
- New orders write checkout event in same transaction as stock reservation/cart clearing. Customer may cancel pending unpaid COD only. Admin moves forward one step or cancels unpaid COD before shipping. Locks order then restores reserved stock and records cancellation atomically. Cancelled/delivered terminal. Legacy orders lack reservation marker: no customer self-cancel, admin cancellation requires manual reconciliation acknowledgement and does not automatically restock. Shipped/paid refunds/returns are separate processes.
- Tracking is administrator-updated status timeline with optional courier/tracking number, not GPS/courier API. Legacy order timestamps are not invented.
- Account deletion cascades order events via order FK.

## Deployment
1. Back up DB/API/admin. Staging: inspect SHOW CREATE TABLE market_orders, market_order_items, market_products, market_cart. Confirm InnoDB, market_orders.id type matches event FK (adapt migration if needed), product ID behavior, status enums, money widths and unique cart index.
2. Run backend/migrations/20261125_marketplace_order_management.sql; verify singleton settings row and event FK; rate initially zero.
3. Compare and deploy _orders.php, cart.php, orders.php to api/marketplace/ and marketplace_admin.php to web root. Existing .cpanel.yml does not copy API/SQL. Updated admin disables order mutations if helper/schema unavailable. Deploy API/helper and migration before admin and APK. Keep db.php, auth and uploads unchanged.
4. Verify staging, retain zero rate until business approves rate and updated clients are ready.
5. Rollback: do not revert to old admin cancellation after new orders created without inventory/event reconciliation. Preserve event and settings data.

## QA
- PHP lint, php backend/tests/marketplace_order_policy_test.php, Flutter analyze/test/build.
- Empty/nonempty cart, free/nonzero rate, stale quote and stock errors, old app rejection with nonzero fee, saved delivery charge unaffected by later edits.
- Two accounts: unauthorized detail/cancel denied; expired token; existing history readable.
- Concurrent admin/customer cancellation or status transition: one succeeds, stock restored once; missing product rolls back; paid/shipped/delivered blocked; legacy stock manually reconciled.
- Admin CSRF, invalid jump, courier data, real timestamps, account deletion cascade and transaction failure. Catalog, services and order placement regression.
- Test slow network, duplicate taps, stale quote, device refresh. No production integration test performed.
