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
  MarketCart({required this.items, required this.subtotal, this.deliveryCharge = 0, double? total})
      : total = total ?? subtotal + deliveryCharge;
  final List<MarketCartLine> items;
  final double subtotal;
  final double deliveryCharge;
  final double total;
  int get count => items.fold(0, (n, line) => n + line.quantity);

  factory MarketCart.fromResponse(Map<String, dynamic> response) {
    final data = marketObject(response['data']);
    final items = data['items'];
    if (items is! List) throw const FormatException('Invalid cart items');
    return MarketCart(
      items: items.map((e) => MarketCartLine.fromJson(marketObject(e))).toList(),
      subtotal: marketMoney(data['subtotal']),
      deliveryCharge: marketMoney(data['delivery_charge'] ?? 0),
      total: data['total_amount'] == null ? null : marketMoney(data['total_amount']),
    );
  }
}

class MarketOrder {
  MarketOrder.fromJson(Map<String, dynamic> json)
      : id = int.parse(json['id'].toString()),
        number = json['order_number'].toString(),
        total = marketMoney(json['total_amount']),
        subtotal = marketMoney(json['subtotal'] ?? json['total_amount']),
        deliveryCharge = marketMoney(json['delivery_charge'] ?? 0),
        status = json['order_status'].toString(),
        paymentStatus = json['payment_status'].toString(),
        paymentMethod = json['payment_method'].toString(),
        createdAt = json['created_at']?.toString() ?? '';

  final int id;
  final String number;
  final double total;
  final double subtotal;
  final double deliveryCharge;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final String createdAt;
}

class MarketOrderLine {
  MarketOrderLine.fromJson(Map<String, dynamic> json)
      : name = json['product_name']?.toString() ?? '',
        sku = json['product_sku']?.toString() ?? '',
        quantity = int.parse(json['quantity'].toString()),
        unitPrice = marketMoney(json['unit_price']),
        total = marketMoney(json['total_price']);

  final String name;
  final String sku;
  final int quantity;
  final double unitPrice;
  final double total;
}

class MarketOrderEvent {
  MarketOrderEvent.fromJson(Map<String, dynamic> json)
      : status = json['order_status'].toString(),
        createdAt = json['created_at']?.toString() ?? '',
        courier = json['courier_name']?.toString() ?? '',
        trackingNumber = json['tracking_number']?.toString() ?? '';

  final String status;
  final String createdAt;
  final String courier;
  final String trackingNumber;
}

class MarketOrderDetail {
  MarketOrderDetail.fromJson(Map<String, dynamic> json)
      : order = MarketOrder.fromJson(json),
        customer = json['customer_name']?.toString() ?? '',
        mobile = json['mobile_number']?.toString() ?? '',
        address = json['delivery_address']?.toString() ?? '',
        note = json['customer_note']?.toString() ?? '',
        canCancel = json['can_cancel'] == true,
        items = (json['items'] as List)
            .map((item) => MarketOrderLine.fromJson(marketObject(item))).toList(),
        events = (json['events'] as List)
            .map((item) => MarketOrderEvent.fromJson(marketObject(item))).toList();

  final MarketOrder order;
  final String customer;
  final String mobile;
  final String address;
  final String note;
  final bool canCancel;
  final List<MarketOrderLine> items;
  final List<MarketOrderEvent> events;
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
