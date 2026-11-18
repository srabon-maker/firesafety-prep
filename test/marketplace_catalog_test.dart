import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/marketplace_item.dart';
import 'package:fire_safety_job_prep/services/marketplace_api_service.dart';

void main() {
  test('parses the deployed PHP products.php response including nulls', () {
    final products = MarketplaceApiService.parseCatalogResponse({
      'success': true,
      'data': [
        {
          'id': 1,
          'category_id': null,
          'category_name': '',
          'name': 'marketplace',
          'slug': 'marketplace-799aa53a74b0f039',
          'sku': 'dhddhd',
          'description': '',
          'price': '1222.00',
          'compare_price': '100000.00',
          'stock_quantity': 10,
          'image_url': null,
          'is_featured': 0,
        }
      ],
    }, isService: false);

    final item = products.single;
    expect(item.id, '1');
    expect(item.name, 'marketplace');
    expect(item.categoryId, isNull);
    expect(item.category, isEmpty);
    expect(item.price, 1222);
    expect(item.comparePrice, 100000);
    expect(item.stock, 10);
    expect(item.imageUrl, isNull);
    expect(item.canAddToCart, isTrue);
    expect(item.priceLabel, '৳1222');
  });

  test('out-of-stock or unknown-stock products cannot be added to cart', () {
    final outOfStock = MarketplaceItem.fromJson({
      'id': 2,
      'name': 'Helmet',
      'price': '500.00',
      'stock_quantity': 0,
    }, isService: false);
    final missingStock = MarketplaceItem.fromJson({
      'id': 3,
      'name': 'Gloves',
      'price': '300.00',
    }, isService: false);
    expect(outOfStock.canAddToCart, isFalse);
    expect(missingStock.canAddToCart, isFalse);
  });

  test('parses service pricing types from PHP services.php', () {
    final services = MarketplaceApiService.parseCatalogResponse({
      'success': true,
      'data': [
        {
          'id': 7,
          'category_id': 3,
          'category_name': 'পরিদর্শন',
          'name': 'ফায়ার সেফটি পরিদর্শন',
          'description': '',
          'pricing_type': 'starting',
          'price': '1500.00',
          'image_url': null,
          'is_featured': 1,
        },
        {
          'id': 8,
          'name': 'ফায়ার সেফটি প্রশিক্ষণ',
          'pricing_type': 'quote',
          'price': null,
        },
      ],
    }, isService: true);
    expect(services.first.categoryId, '3');
    expect(services.first.priceLabel, 'শুরু ৳1500');
    expect(services.first.isFeatured, isTrue);
    expect(services.first.canAddToCart, isFalse);
    expect(services.last.priceLabel, 'মূল্য জানতে যোগাযোগ করুন');
  });

  test('categories.php filters categories by product or service', () {
    final response = {
      'success': true,
      'data': [
        {'id': 1, 'name': 'যন্ত্রপাতি', 'category_type': 'product'},
        {'id': 2, 'name': 'সেবা', 'category_type': 'service'},
        {'id': 3, 'name': 'উভয়', 'category_type': 'both'},
      ],
    };
    final productCategories =
        MarketplaceApiService.parseCategoriesResponse(
          response,
          isService: false,
        );
    final serviceCategories =
        MarketplaceApiService.parseCategoriesResponse(
          response,
          isService: true,
        );
    expect(productCategories.map((c) => c.id).toList(), ['1', '3']);
    expect(serviceCategories.map((c) => c.id).toList(), ['2', '3']);
  });

  test('nested catalog format remains supported', () {
    final items = MarketplaceApiService.parseCatalogResponse({
      'success': true,
      'data': {
        'services': [
          {'id': 7, 'title': 'Fire Safety Inspection'}
        ],
      },
    }, isService: true);
    expect(items.single.isService, isTrue);
  });

  test('unknown API response structure fails visibly', () {
    expect(
      () => MarketplaceApiService.parseCatalogResponse(
        {'success': true, 'unexpected': []},
        isService: false,
      ),
      throwsFormatException,
    );
  });

  test('malformed category is rejected instead of silently disappearing', () {
    expect(
      () => MarketplaceApiService.parseCategoriesResponse({
        'success': true,
        'data': [
          {'id': 1, 'name': 'Bad category', 'category_type': 'unknown'}
        ],
      }, isService: false),
      throwsFormatException,
    );
  });
}
