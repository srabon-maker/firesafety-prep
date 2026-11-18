# Marketplace PHP API integration (feature branch)

The deployed API base is configured in `lib/services/marketplace_api_service.dart`.
Authenticated requests send `Authorization: Bearer <session_token>` from
`AuthService`'s secure storage. The public product/service catalog remains
accessible without signing in.

## Implemented

- `GET cart.php`: server cart items and server subtotal
- `POST cart.php`: `{"action":"set","product_id":1,"quantity":2}` or
  `{"action":"remove","product_id":1}`; quantity 0 removes a line
- `POST orders.php`: name, mobile, address, optional note, `payment_method: cod`
- `GET orders.php`: last 100 orders, with order/payment statuses
- `POST service_requests.php`: service ID, contact, location, optional
  company, details and ISO preferred date
- `GET service_requests.php`: last 100 requests and statuses

The API enforces inventory, recalculates totals, decrements stock and clears
the cart after checkout. The client never sends a total or product price.
Service booking is a request, **not** a confirmed appointment or payment.

## QA checklist (before merging)

1. Run `flutter pub get`, `flutter analyze`, `flutter test` with Codemagic.
2. Confirm public catalog works when logged out; cart/history/booking require login.
3. Add a product, restart app, confirm the server cart persists.
4. Change quantity, remove an item, test stock and 99-item limits.
5. Submit one COD order, verify the order number and history; cart clears.
6. Verify the MySQL stock decreases exactly once and order appears in admin.
7. Book a service with/without preferred date; verify request history and admin.
8. Check expired session, no network, API errors and repeated taps.
9. Verify the deployed PHP files match the reviewed backend package.
10. Do not test checkout with real orders unless an admin can cancel test orders.

## Current limits

No online payment, delivery pricing, order cancellation, order line detail,
booking confirmation or push notifications. PHP currently uses zero delivery
charge. API error responses must not expose credentials. Flutter SDK was not
available in the assistant execution environment, so build/device tests are
pending Codemagic verification.
