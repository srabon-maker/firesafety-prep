/// A product or service returned by the deployed Marketplace PHP API.
class MarketplaceItem {
  const MarketplaceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.isService,
    this.categoryId,
    this.price,
    this.comparePrice,
    this.pricingType,
    this.imageUrl,
    this.stock,
    this.isFeatured = false,
  });

  final String id;
  final String name;
  final String category;
  final String? categoryId;
  final String description;
  final bool isService;
  final double? price;
  final double? comparePrice;
  final String? pricingType;
  final String? imageUrl;
  final int? stock;
  final bool isFeatured;

  /// The deployed product API always supplies stock_quantity. Treat missing
  /// inventory as unavailable instead of allowing an unsafe cart action.
  bool get canAddToCart =>
      !isService && price != null && stock != null && stock! > 0;

  String get priceLabel {
    if (isService && pricingType == 'quote') {
      return 'মূল্য জানতে যোগাযোগ করুন';
    }
    if (price == null) return 'মূল্য জানতে যোগাযোগ করুন';
    final formatted = '৳${price!.toStringAsFixed(price! % 1 == 0 ? 0 : 2)}';
    return isService && pricingType == 'starting'
        ? 'শুরু $formatted'
        : formatted;
  }

  static double? _money(dynamic value) {
    if (value == null) return null;
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(
            value.toString().replaceAll(',', '').replaceAll('৳', '').trim(),
          );
    return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
  }

  factory MarketplaceItem.fromJson(
    Map<String, dynamic> json, {
    required bool isService,
  }) {
    final categoryValue = json['category_name'] ?? json['category'];
    final categoryName = categoryValue is Map
        ? (categoryValue['name'] ?? '').toString()
        : (categoryValue ?? '').toString();
    final imageValue = json['image_url'] ?? json['image'] ?? json['thumbnail'];
    final image = imageValue?.toString().trim();
    final stockValue = json['stock_quantity'] ?? json['stock'];
    final stock = stockValue is num
        ? stockValue.toInt()
        : int.tryParse((stockValue ?? '').toString());
    final rawCategoryId = json['category_id'];

    return MarketplaceItem(
      id: (json['id'] ?? json['product_id'] ?? json['service_id'] ?? '')
          .toString(),
      name: (json['name'] ?? json['title'] ?? '').toString().trim(),
      category: categoryName.trim(),
      categoryId: rawCategoryId == null ? null : rawCategoryId.toString(),
      description: (json['description'] ?? '').toString(),
      price: _money(json['price'] ?? json['sale_price']),
      comparePrice: isService ? null : _money(json['compare_price']),
      pricingType: isService ? json['pricing_type']?.toString() : null,
      imageUrl: image == null || image.isEmpty ? null : image,
      stock: isService ? null : stock,
      isFeatured: json['is_featured'] == true ||
          json['is_featured'] == 1 ||
          json['is_featured'] == '1',
      isService: isService,
    );
  }
}
