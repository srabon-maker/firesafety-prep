import 'package:flutter_test/flutter_test.dart';
import '../lib/services/career_service.dart';

void main() {
  test('career external links require HTTPS without credentials', () {
    expect(CareerService.safeLink('https://example.com/course'), isNotNull);
    expect(CareerService.safeLink('http://example.com'), isNull);
    expect(CareerService.safeLink('javascript:alert(1)'), isNull);
    expect(CareerService.safeLink('https://user@example.com'), isNull);
  });
  test('career list parsing preserves server rows', () {
    expect(CareerService.rows({'data': [{'title':'Fire Safety'}]}).single['title'], 'Fire Safety');
  });
}
