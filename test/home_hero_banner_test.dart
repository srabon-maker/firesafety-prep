import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/widgets/home_hero_banner.dart';

const items = <Map<String,dynamic>>[
  {'id':'1','title':'First banner','body':'First details','target':'jobs'},
  {'id':'2','title':'Second banner','body':'Second details','target':'notes'},
];

Widget app(List<Map<String,dynamic>> rows, ValueChanged<Map<String,dynamic>> open,
    {bool reducedMotion = false}) => MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: HomeHeroBanner(items:rows,onOpen:open),
      ),
    )));

void main() {
  testWidgets('single banner is clickable without slide controls', (tester) async {
    Map<String,dynamic>? opened;
    await tester.pumpWidget(app([items.first], (row)=>opened=row));
    expect(find.text('First banner'), findsOneWidget);
    expect(find.byTooltip('Pause auto slide'), findsNothing);
    await tester.tap(find.text('First banner'));
    expect(opened?['target'], 'jobs');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('automatically advances, pauses, and supports dot navigation', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(app(items, (_){}));
    await tester.pump(const Duration(seconds:5));
    await tester.pumpAndSettle();
    final controller=tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(controller.page, closeTo(1, .01));
    await tester.tap(find.byTooltip('Pause auto slide'));
    await tester.pump();
    await tester.pump(const Duration(seconds:6));
    expect(controller.page, closeTo(1, .01));
    await tester.tap(find.bySemanticsLabel('Banner 1'));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(0, .01));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion disables automatic scrolling', (tester) async {
    await tester.pumpWidget(app(items, (_) {}, reducedMotion:true));
    await tester.pump(const Duration(seconds:6));
    final controller=tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(controller.page, closeTo(0, .01));
    expect(find.byTooltip('Pause auto slide'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
