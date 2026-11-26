import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/marketplace_engagement.dart';

void main() {
  test('parse real ratings and active product links from API', () {
    final data = MarketplaceEngagement.fromJson({
      'ratings': [{'product_id': 3, 'average_rating': '4.2', 'review_count': '5'}],
      'banners': [{'product_id': 3,'title':'Offer','subtitle':'','image_url':null}],
    });
    expect(data.ratings['3']!.average, 4.2);
    expect(data.ratings['3']!.count, 5);
    expect(data.banners.single.productId, '3');
  });
  test('unrated or invalid values are not displayed as invented stars', () {
    expect(ProductRating.fromJson({'average_rating':null,'review_count':0}).count,0);
    expect(ProductRating.fromJson({'average_rating':'6','review_count':1}).count,0);
    expect(ProductRating.fromJson({'average_rating':'NaN','review_count':1}).count,0);
  });
}
