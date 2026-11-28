import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/job_circular.dart';
import 'package:fire_safety_job_prep/models/study_note.dart';
import 'package:fire_safety_job_prep/screens/home_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

Future<void> mountHome(WidgetTester tester, String language,
    {ThemeMode mode = ThemeMode.dark, double scale = 1, double width = 360,
    List<String> sections = const ['marketplace', 'jobs', 'notes']}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme, themeMode: mode,
    locale: Locale(language), supportedLocales: const [Locale('bn'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 24),
        viewPadding: const EdgeInsets.only(top: 24),
        textScaler: TextScaler.linear(scale)), child: child!),
    home: Scaffold(body: HomePage(
      loadHome: () async => {'sections': sections},
      loadJobs: () async => [JobCircular(id: 1, organization: 'Example Company',
        title: 'Sample job', location: 'Dhaka', publishedAt: DateTime(2026, 1, 1))],
      loadNotes: () async => const StudyNotesPage(notes: [], categories: [], page: 1, totalPages: 1, total: 0),
    )),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Bengali home preserves all ten shortcuts and compact grids', (tester) async {
    await mountHome(tester, 'bn');
    for (final label in ['চাকরির খবর','প্রশ্ন ব্যাংক','স্টাডি নোট','মডেল টেস্ট',
      'ইন্টারভিউ','আমার প্রস্তুতি','চাকরির\nঅ্যালার্ট','মক\nইন্টারভিউ','প্রশিক্ষণ\nও কোর্স','পেশাজীবী\nডিরেক্টরি']) {
      expect(find.text(label), findsOneWidget);
    }
    final grids = tester.widgetList<GridView>(find.byType(GridView)).toList();
    final first = grids[0].gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    final second = grids[1].gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(first.crossAxisCount, 3);
    expect(first.mainAxisExtent, 88);
    expect(second.crossAxisCount, 4);
    expect(second.mainAxisExtent, 84);
    final iconTops = [for (final target in ['alerts','mock','courses','directory'])
      tester.getTopLeft(find.byKey(ValueKey('home-career-icon-$target'))).dy];
    expect(iconTops.toSet().length, 1);
    final mockCard = tester.widget<Card>(find.byKey(const ValueKey('home-career-mock')));
    final shape = mockCard.shape! as RoundedRectangleBorder;
    expect(shape.side.color.a, closeTo(.62, .01));
    expect(find.text('মার্কেটপ্লেস'), findsOneWidget);
    expect(find.text('Fire Safety BD'), findsOneWidget);
    expect(find.byTooltip('নোটিফিকেশন'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Safe area protects scroll viewport and previews remain available', (tester) async {
    await mountHome(tester, 'en', mode: ThemeMode.light);
    final list = find.byType(ListView).first;
    expect(tester.getTopLeft(list).dy, greaterThanOrEqualTo(24));
    final status = tester.widget<DecoratedBox>(find.byKey(const ValueKey('home-status-gradient')));
    expect((status.decoration as BoxDecoration).gradient, isA<LinearGradient>());
    expect(find.text('Marketplace'), findsOneWidget);
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(list).dy, greaterThanOrEqualTo(24));
    expect(find.text('Sample job'), findsOneWidget);
    expect(find.text('Example Company • Dhaka'), findsOneWidget);
    expect(find.text('No notes published.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text narrow home keeps shortcuts and remote section settings', (tester) async {
    await mountHome(tester, 'en', scale: 1.6, width: 320, sections: []);
    final grids = tester.widgetList<GridView>(find.byType(GridView)).toList();
    expect((grids.first.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 2);
    expect(find.text('Marketplace'), findsNothing);
    expect(find.text('My preparation'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Professional\ndirectory'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
