import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/marketplace_transaction.dart';

void main() {
  test('cart.php returns server subtotal and cart lines', () {
    final cart = MarketCart.fromResponse({
      'success': true,
      'data': {
        'items': [
          {
            'product_id': 1,
            'quantity': 2,
            'name': 'Extinguisher',
            'price': '1222.00',
            'stock_quantity': 10,
            'image_url': null,
            'line_total': '2444.00',
          },
        ],
        'subtotal': '2444.00',
      },
    });
    expect(cart.count, 2);
    expect(cart.subtotal, 2444);
    expect(cart.items.single.productId, 1);
    expect(cart.items.single.lineTotal, 2444);
  });

  test('empty cart has zero subtotal', () {
    final cart = MarketCart.fromResponse({
      'success': true,
      'data': {'items': [], 'subtotal': '0.00'},
    });
    expect(cart.count, 0);
    expect(cart.items, isEmpty);
  });

  test('orders.php list maps status, payment and amount', () {
    final orders = marketList({
      'success': true,
      'data': [
        {
          'id': 11,
          'order_number': 'FS-20261118-ABC',
          'subtotal': '200.00',
          'delivery_charge': '0.00',
          'total_amount': '200.00',
          'payment_method': 'cod',
          'payment_status': 'pending',
          'order_status': 'pending',
          'created_at': '2026-11-18 12:00:00',
        }
      ],
    }).map((e) => MarketOrder.fromJson(marketObject(e))).toList();
    expect(orders.single.number, 'FS-20261118-ABC');
    expect(orders.single.total, 200);
    expect(orders.single.paymentMethod, 'cod');
    expect(orders.single.status, 'pending');
  });

  test('service_requests.php list maps service and preferred date', () {
    final requests = marketList({
      'success': true,
      'data': [
        {
          'id': 3,
          'request_number': 'SR-20261118-ABC',
          'service_id': 7,
          'service_name': 'Fire inspection',
          'service_location': 'Dhaka',
          'preferred_date': '2026-11-25',
          'status': 'pending',
          'created_at': '2026-11-18 12:00:00',
        }
      ],
    }).map((e) => MarketServiceRequest.fromJson(marketObject(e))).toList();
    expect(requests.single.serviceName, 'Fire inspection');
    expect(requests.single.preferredDate, '2026-11-25');
    expect(requests.single.status, 'pending');
  });

  test('rejects malformed and negative financial data', () {
    expect(() => marketMoney('-2'), throwsFormatException);
    expect(() => marketMoney('NaN'), throwsFormatException);
    expect(() => marketList({'data': {}}), throwsFormatException);
    expect(() => MarketCart.fromResponse({
      'data': {'items': 'invalid', 'subtotal': '0.00'},
    }), throwsFormatException);
  });
}
