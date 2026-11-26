import 'package:flutter_test/flutter_test.dart';
import '../lib/models/category_labels.dart';
void main() {
  test('display language keeps canonical query key unchanged', () {
    final row={'category':'ফায়ার সেইফটি','category_name_bn':'ফায়ার সেইফটি','category_name_en':'Fire Safety'};
    expect(categoryDisplayFromRow(row,'category','en'),'Fire Safety');
    expect(categoryDisplayFromRow(row,'category','bn'),'ফায়ার সেইফটি');
    expect(row['category'],'ফায়ার সেইফটি');
    expect(categoryMatches(row,'category','FIRE'),isTrue);
    expect(categoryMatches(row,'category','ফায়ার'),isTrue);
  });
  test('acronyms and fallback', () {
    expect(categoryDisplayName('NFPA','NFPA','NFPA','bn'),'NFPA');
    expect(categoryDisplayName('Legacy',null,'','en'),'Legacy');
  });
}
