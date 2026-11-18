/// A catalog item returned by the Fire Safety BD marketplace API.
class MarketplaceItem {
  const MarketplaceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.isService,
    this.price,
    this.imageUrl,
    this.stock,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final bool isService;
  final double? price;
  final String? imageUrl;
  final int? stock;

  bool get canAddToCart =>
      !isService && price != null && (stock == null || stock! > 0);

  String get priceLabel {
    if (price == null) return 'মূল্য জানতে যোগাযোগ করুন';
    return '৳${price!.toStringAsFixed(price! % 1 == 0 ? 0 : 2)}';
  }

  factory MarketplaceItem.fromJson(
    Map<String, dynamic> json, {
    required bool isService,
  }) {
    final categoryValue = json['category_name'] ?? json['category'];
    final categoryName = categoryValue is Map
        ? (categoryValue['name'] ?? '').toString()
        : (categoryValue ?? '').toString();
    final imageValue =
        json['image_url'] ?? json['image'] ?? json['thumbnail'];
    final image = imageValue?.toString().trim();
    final priceValue = json['price'] ?? json['sale_price'];
    final price = priceValue is num
        ? priceValue.toDouble()
        : double.tryParse(
            (priceValue ?? '').toString().replaceAll(',', '').replaceAll('৳', '').trim(),
          );
    final stockValue = json['stock_quantity'] ?? json['stock'];
    final stock = stockValue is num
        ? stockValue.toInt()
        : int.tryParse((stockValue ?? '').toString());

    return MarketplaceItem(
      id: (json['id'] ?? json['product_id'] ?? json['service_id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? '').toString().trim(),
      category: categoryName.trim(),
      description: (json['description'] ?? '').toString(),
      price: price != null && price >= 0 ? price : null,
      imageUrl: image == null || image.isEmpty ? null : image,
      stock: stock,
      isService: isService,
    );
  }
}
