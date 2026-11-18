import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/marketplace_item.dart';
import 'package:fire_safety_job_prep/services/marketplace_api_service.dart';

void main() {
  test('parses a product with numeric string price', () {
    final item = MarketplaceItem.fromJson({
      'id': 12,
      'name': 'Fire Extinguisher',
      'category_name': 'Fire Equipment',
      'price': '1,250',
      'stock': 4,
    }, isService: false);

    expect(item.id, '12');
    expect(item.price, 1250);
    expect(item.canAddToCart, isTrue);
    expect(item.category, 'Fire Equipment');
  });

  test('parses product catalog from data array', () {
    final items = MarketplaceApiService.parseCatalogResponse({
      'success': true,
      'data': [
        {'id': 1, 'name': 'Helmet', 'price': 500}
      ],
    }, isService: false);
    expect(items.single.name, 'Helmet');
  });

  test('parses nested service catalog', () {
    final items = MarketplaceApiService.parseCatalogResponse({
      'data': {
        'services': [
          {'id': 7, 'title': 'Fire Safety Inspection'}
        ],
      },
    }, isService: true);
    expect(items.single.isService, isTrue);
    expect(items.single.canAddToCart, isFalse);
  });

  test('unknown response structure is not treated as empty catalog', () {
    expect(
      () => MarketplaceApiService.parseCatalogResponse(
        {'success': true, 'unexpected': []},
        isService: false,
      ),
      throwsFormatException,
    );
  });
}
