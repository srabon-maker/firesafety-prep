import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/learning_library_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

const sample = <String, dynamic>{
  'roles': ['Officer'],
  'industries': ['Factory'],
  'data': [
    {'id': 1, 'title': 'নমুনা প্রশ্ন', 'title_en': 'Sample question',
      'body': 'নমুনা উত্তর', 'body_en': 'Sample answer', 'role_name': 'Officer'},
    {'id': 2, 'title': 'প্রিমিয়াম প্রশ্ন', 'locked': true, 'body': 'Protected answer'},
  ],
  'has_more': true,
};

Future<void> mountInterview(WidgetTester tester, ThemeMode mode, String language,
    Future<Map<String, dynamic>> Function(Map<String, String>) loader,
    {double scale = 1}) async {
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
    home: InterviewPage(loadInterviews: loader),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Dark Bengali interview displays compact header and protected preview', (tester) async {
    await mountInterview(tester, ThemeMode.dark, 'bn', (_) async => sample);
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(find.text('ইন্টারভিউ প্রস্তুতি'), findsOneWidget);
    expect(find.text('0/120'), findsNothing);
    expect(find.text('সব পদ'), findsOneWidget);
    expect(find.text('সব ইন্ডাস্ট্রি'), findsOneWidget);
    expect(find.text('2টি প্রশ্ন (এই পেজে)'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Protected answer'), findsNothing);
    await tester.tap(find.text('নমুনা প্রশ্ন'));
    await tester.pumpAndSettle();
    expect(find.text('নমুনা উত্তর'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sample question'));
    await tester.pumpAndSettle();
    expect(find.text('Sample answer'), findsOneWidget);
    expect(find.text('প্রিমিয়াম প্রশ্ন'), findsOneWidget);
    expect(find.text('Protected answer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English light interview preserves filter and pagination parameters', (tester) async {
    final calls = <Map<String, String>>[];
    await mountInterview(tester, ThemeMode.light, 'en', (filters) async {
      calls.add(Map.of(filters));
      return sample;
    });
    expect(find.text('Interview prep'), findsOneWidget);
    await tester.tap(find.text('All roles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Officer').last);
    await tester.pumpAndSettle();
    expect(calls.last['role'], 'Officer');
    await tester.enterText(find.byType(TextField), 'sample');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(calls.last['search'], 'sample');
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(calls.last['page'], '2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text and empty results remain accessible', (tester) async {
    await mountInterview(tester, ThemeMode.dark, 'en',
      (_) async => const {'data': [], 'roles': [], 'industries': []}, scale: 1.6);
    expect(find.text('No questions found.'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
