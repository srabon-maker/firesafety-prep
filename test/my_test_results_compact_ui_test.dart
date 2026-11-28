import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/tests_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

Future<void> mountResults(WidgetTester tester, {
  required Future<List<Map<String, dynamic>>> Function() load,
  String language = 'bn',
  ThemeMode mode = ThemeMode.dark,
  double width = 360,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme, themeMode: mode,
    locale: Locale(language), supportedLocales: const [Locale('bn'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: MyTestResultsPage(loadResults: load),
  ));
  await tester.pumpAndSettle();
}

const sample = <Map<String, dynamic>>[
  {'attempt_id': '21', 'title': 'Sample test', 'score': '8.00',
    'total_marks': '10.00', 'question_count': '10', 'correct_count': '8',
    'incorrect_count': '2', 'unanswered_count': '0', 'passed': '1'},
  {'attempt_id': 20, 'title': 'Older test', 'score': 4,
    'total_marks': 10, 'question_count': 10, 'correct_count': 4,
    'incorrect_count': 6, 'unanswered_count': 0, 'passed': 0},
];

void main() {
  testWidgets('Compact Bengali results header, error retry and genuine empty state', (tester) async {
    var calls = 0;
    await mountResults(tester, load: () async {
      if (++calls < 3) throw StateError('offline');
      return [];
    });
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(tester.widget<Text>(find.text('আমার পরীক্ষার ফলাফল')).style?.fontSize, 15.5);
    expect(find.textContaining('ফলাফল লোড করা যায়নি।'), findsOneWidget);
    await tester.tap(find.text('আবার চেষ্টা করুন'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('ফলাফল লোড করা যায়নি।'), findsOneWidget);
    await tester.tap(find.byTooltip('রিফ্রেশ'));
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(find.text('এখনো কোনো প্রকাশিত ফলাফল নেই।'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Numeric strings and numbers preserve real results and statistics', (tester) async {
    await mountResults(tester, language: 'en', mode: ThemeMode.light, load: () async => sample);
    expect(find.text('Preparation summary'), findsOneWidget);
    expect(find.text('60.0%'), findsWidgets);
    expect(find.text('80.0%'), findsWidgets);
    expect(find.text('Recent score trend'), findsOneWidget);
    final target = find.text('Score: 8.00 / 10.00');
    await tester.scrollUntilVisible(target, 150);
    await tester.pumpAndSettle();
    expect(target, findsOneWidget);
    expect(find.text('Pass'), findsOneWidget);
    expect(find.text('View result details'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Narrow large text results remain usable', (tester) async {
    await mountResults(tester, language: 'en', width: 320, scale: 1.6, load: () async => sample);
    expect(find.text('My Exam Results'), findsOneWidget);
    final target = find.text('Score: 4 / 10');
    await tester.scrollUntilVisible(target, 150);
    await tester.pumpAndSettle();
    expect(target, findsOneWidget);
    expect(find.text('Fail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
