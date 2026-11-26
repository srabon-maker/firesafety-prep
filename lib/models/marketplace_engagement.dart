class ProductRating {
  const ProductRating(this.average, this.count);
  final double average;
  final int count;
  factory ProductRating.fromJson(Map<String, dynamic> data) {
    final average = double.tryParse('${data['average_rating']}') ?? 0;
    final count = int.tryParse('${data['review_count']}') ?? 0;
    return average.isFinite && average >= 1 && average <= 5 && count > 0
        ? ProductRating(average, count) : const ProductRating(0, 0);
  }
}

class ProductBanner {
  const ProductBanner(this.productId, this.title, this.subtitle, this.imageUrl);
  final String productId, title, subtitle, imageUrl;
  factory ProductBanner.fromJson(Map<String, dynamic> data) => ProductBanner(
    '${data['product_id'] ?? ''}', '${data['title'] ?? ''}',
    '${data['subtitle'] ?? ''}', '${data['image_url'] ?? ''}');
}

class MarketplaceEngagement {
  const MarketplaceEngagement(this.ratings, this.banners);
  final Map<String, ProductRating> ratings;
  final List<ProductBanner> banners;
  factory MarketplaceEngagement.fromJson(Map<String, dynamic> data) {
    final ratings = data['ratings'] as List;
    final banners = data['banners'] as List;
    return MarketplaceEngagement({
      for (final row in ratings.whereType<Map>())
        if (row['product_id'] != null)
          '${row['product_id']}': ProductRating.fromJson(Map<String, dynamic>.from(row)),
    }, banners.whereType<Map>().map((row) => ProductBanner.fromJson(
      Map<String, dynamic>.from(row))).where((b) => b.productId.isNotEmpty && b.title.isNotEmpty).toList());
  }
}
