/// Typed responses from the deployed Fire Safety BD Marketplace PHP APIs.
double marketMoney(dynamic raw) {
  final value = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
  if (value == null || !value.isFinite || value < 0) {
    throw const FormatException('Invalid marketplace amount');
  }
  return value;
}

List<dynamic> marketList(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is! List) throw const FormatException('Expected a list in data');
  return data;
}

Map<String, dynamic> marketObject(dynamic raw) {
  if (raw is! Map) throw const FormatException('Invalid marketplace item');
  return Map<String, dynamic>.from(raw);
}

class MarketCartLine {
  MarketCartLine.fromJson(Map<String, dynamic> json)
      : productId = int.parse(json['product_id'].toString()),
        name = json['name'].toString(),
        quantity = int.parse(json['quantity'].toString()),
        stock = int.parse(json['stock_quantity'].toString()),
        price = marketMoney(json['price']),
        imageUrl = json['image_url']?.toString();

  final int productId;
  final String name;
  final int quantity;
  final int stock;
  final double price;
  final String? imageUrl;
  double get lineTotal => price * quantity;
}

class MarketCart {
  MarketCart({required this.items, required this.subtotal});
  final List<MarketCartLine> items;
  final double subtotal;
  int get count => items.fold(0, (n, line) => n + line.quantity);

  factory MarketCart.fromResponse(Map<String, dynamic> response) {
    final data = marketObject(response['data']);
    final items = data['items'];
    if (items is! List) throw const FormatException('Invalid cart items');
    return MarketCart(
      items: items.map((e) => MarketCartLine.fromJson(marketObject(e))).toList(),
      subtotal: marketMoney(data['subtotal']),
    );
  }
}

class MarketOrder {
  MarketOrder.fromJson(Map<String, dynamic> json)
      : id = int.parse(json['id'].toString()),
        number = json['order_number'].toString(),
        total = marketMoney(json['total_amount']),
        status = json['order_status'].toString(),
        paymentStatus = json['payment_status'].toString(),
        paymentMethod = json['payment_method'].toString(),
        createdAt = json['created_at']?.toString() ?? '';

  final int id;
  final String number;
  final double total;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final String createdAt;
}

class MarketServiceRequest {
  MarketServiceRequest.fromJson(Map<String, dynamic> json)
      : id = int.parse(json['id'].toString()),
        number = json['request_number'].toString(),
        serviceName = json['service_name']?.toString() ?? '',
        location = json['service_location']?.toString() ?? '',
        preferredDate = json['preferred_date']?.toString(),
        status = json['status'].toString(),
        createdAt = json['created_at']?.toString() ?? '';

  final int id;
  final String number;
  final String serviceName;
  final String location;
  final String? preferredDate;
  final String status;
  final String createdAt;
}
