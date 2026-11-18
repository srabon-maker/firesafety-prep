import '../models/marketplace_transaction.dart';
import 'marketplace_api_service.dart';

/// The PHP API owns prices, stock checks and order totals. Never trust a
/// client-calculated total when placing an order.
class MarketplaceTransactionService {
  MarketplaceTransactionService._();
  static final instance = MarketplaceTransactionService._();
  final _api = MarketplaceApiService.instance;

  Future<MarketCart> getCart() async =>
      MarketCart.fromResponse(await _api.get('cart.php', requireAuth: true));

  Future<MarketCart> setQuantity(int productId, int quantity) async {
    if (productId < 1 || quantity < 0 || quantity > 99) {
      throw ArgumentError('Invalid cart quantity');
    }
    return MarketCart.fromResponse(await _api.post('cart.php', body: {
      'action': 'set', 'product_id': productId, 'quantity': quantity,
    }));
  }

  Future<MarketCart> remove(int productId) async =>
      MarketCart.fromResponse(await _api.post('cart.php', body: {
        'action': 'remove', 'product_id': productId,
      }));

  Future<MarketCart> clearCart() async =>
      MarketCart.fromResponse(await _api.post('cart.php', body: {
        'action': 'clear',
      }));

  Future<String> placeOrder({
    required String name,
    required String mobile,
    required String address,
    String note = '',
  }) async {
    final result = await _api.post('orders.php', body: {
      'customer_name': name.trim(),
      'mobile_number': mobile.trim(),
      'delivery_address': address.trim(),
      'customer_note': note.trim(),
      'payment_method': 'cod',
    });
    return marketObject(result['data'])['order_number'].toString();
  }

  Future<List<MarketOrder>> getOrders() async =>
      marketList(await _api.get('orders.php', requireAuth: true))
          .map((e) => MarketOrder.fromJson(marketObject(e))).toList();

  Future<String> requestService({
    required int serviceId,
    required String name,
    required String mobile,
    required String location,
    String company = '',
    String details = '',
    String? preferredDate,
  }) async {
    final result = await _api.post('service_requests.php', body: {
      'service_id': serviceId,
      'customer_name': name.trim(),
      'mobile_number': mobile.trim(),
      'service_location': location.trim(),
      'company_name': company.trim(),
      'request_details': details.trim(),
      'preferred_date': preferredDate,
    });
    return marketObject(result['data'])['request_number'].toString();
  }

  Future<List<MarketServiceRequest>> getServiceRequests() async =>
      marketList(await _api.get('service_requests.php', requireAuth: true))
          .map((e) => MarketServiceRequest.fromJson(marketObject(e))).toList();
}
