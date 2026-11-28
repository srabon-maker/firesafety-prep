import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/tests_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

const tests = <Map<String, dynamic>>[
  {'id': 1, 'title': 'Sample test', 'category_id': 1, 'category_name': 'Fire',
    'question_count': 7, 'duration_minutes': 30, 'total_marks': 7,
    'pass_marks': 4, 'negative_marks_per_question': 0.25,
    'randomize_questions': true, 'max_attempts': 3, 'exam_instructions': 'Read carefully'},
  {'id': 2, 'title': 'Premium test', 'category_id': 2, 'category_name': 'Electrical',
    'question_count': 10, 'duration_minutes': 20, 'total_marks': 10, 'locked': true},
];

Future<void> mountTests(WidgetTester tester, ThemeMode mode, String language,
    {double scale = 1, List<Map<String, dynamic>> data = tests,
    List<Map<String, dynamic>> active = const []}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: mode,
    locale: Locale(language),
    supportedLocales: const [Locale('bn'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: TestsPage(loadTests: () async => data, loadActiveAttempts: () async => active),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Bengali dark list removes banner but preserves exam metadata', (tester) async {
    await mountTests(tester, ThemeMode.dark, 'bn', data: [tests.first]);
    expect(tester.widget<Text>(find.text('মডেল টেস্ট')).style?.fontSize, 15.5);
    expect(find.text('নিজেকে যাচাই করুন'), findsNothing);
    expect(find.byTooltip('আমার ফলাফল'), findsOneWidget);
    expect(find.byTooltip('প্র্যাকটিস ড্যাশবোর্ড'), findsOneWidget);
    expect(find.byTooltip('রিফ্রেশ'), findsOneWidget);
    expect(find.text('Sample test'), findsOneWidget);
    expect(find.text('7 প্রশ্ন'), findsOneWidget);
    expect(find.text('30 মিনিট'), findsOneWidget);
    expect(find.text('7 নম্বর'), findsOneWidget);
    expect(find.text('পাস 4'), findsOneWidget);
    expect(find.text('ভুলে -0.25'), findsOneWidget);
    expect(find.text('প্রশ্নের ক্রম এলোমেলো'), findsOneWidget);
    expect(find.text('সর্বোচ্চ 3 বার'), findsOneWidget);
    expect(find.text('পরীক্ষা শুরু করুন'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English light list retains category filter and premium label', (tester) async {
    await mountTests(tester, ThemeMode.light, 'en');
    expect(find.text('Model Tests'), findsOneWidget);
    expect(find.text('2 tests'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Electrical'));
    await tester.pumpAndSettle();
    expect(find.text('Sample test'), findsNothing);
    expect(find.text('Premium test'), findsOneWidget);
    expect(find.text('View Premium'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Active premium test retains resume action and remaining time', (tester) async {
    await mountTests(tester, ThemeMode.dark, 'en', data: [tests.last],
      active: const [{'test_id': 2, 'title': 'Premium test', 'remaining_seconds': 600}]);
    expect(find.text('Unfinished tests'), findsOneWidget);
    expect(find.text('Time left: 10 min'), findsOneWidget);
    expect(find.text('Resume test'), findsOneWidget);
    expect(find.text('View Premium'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty state at large text size is accessible', (tester) async {
    await mountTests(tester, ThemeMode.dark, 'en', data: [], scale: 1.6);
    expect(find.text('No tests published yet.'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
