/// A category returned by GET api/marketplace/categories.php.
class MarketplaceCategory {
  const MarketplaceCategory({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;
  final String type;

  bool supports({required bool isService}) =>
      type == 'both' || type == (isService ? 'service' : 'product');

  factory MarketplaceCategory.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final name = (json['name'] ?? '').toString().trim();
    final type = (json['category_type'] ?? '').toString().trim();
    if (id.isEmpty ||
        name.isEmpty ||
        !const {'product', 'service', 'both'}.contains(type)) {
      throw const FormatException('ক্যাটাগরির তথ্য সঠিক নয়।');
    }
    return MarketplaceCategory(id: id, name: name, type: type);
  }
}
