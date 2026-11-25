import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/career_quick_links.dart';
import '../lib/services/homepage_service.dart';

void main() {
  test('old API inserts career after marketplace without changing other order', () {
    expect(HomepageService.homeSections(['jobs','marketplace','notes'],careerConfigured:false), ['jobs','marketplace','career','notes']);
    expect(HomepageService.homeSections(['jobs'],careerConfigured:true), ['jobs']);
    expect(HomepageService.homeSections(['career','jobs'],careerConfigured:true), ['career','jobs']);
  });
  testWidgets('compact hub routes all three links and excludes job alert', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SizedBox(
      width: 292, child: CareerQuickLinks(onOpen: opened.add),
    )))));
    for (final section in ['mock','courses','directory']) {
      await tester.tap(find.byKey(ValueKey('career-' + section)));
    }
    expect(opened,['mock','courses','directory']);
    expect(find.byKey(const ValueKey('career-alerts')),findsNothing);
    expect(tester.takeException(),isNull);
  });
}
