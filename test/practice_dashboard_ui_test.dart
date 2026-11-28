import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/tests_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

const _sample = <String, dynamic>{
  'daily_target': 10,
  'today': {'questions': 0, 'correct': 0},
  'overall': {'questions': 10, 'correct': 9, 'streak': 0},
  'weekly': [
    {'date': '2026-11-26', 'questions': 10, 'correct': 9},
  ],
  'weak_subjects': [
    {'category': 'Fire', 'questions': 10, 'accuracy': 90, 'sessions': 1},
  ],
};

Future<void> _mount(WidgetTester tester, {
  required ThemeMode mode,
  required String language,
  Map<String, dynamic> data = _sample,
  double scale = 1,
}) async {
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
    home: PracticeDashboardPage(loadDashboard: () async => data),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Dark dashboard uses readable theme colors and real data', (tester) async {
    await _mount(tester, mode: ThemeMode.dark, language: 'bn');
    expect(find.text('প্র্যাকটিস ড্যাশবোর্ড'), findsOneWidget);
    expect(find.text('0 / 10 প্রশ্ন'), findsOneWidget);
    expect(find.text('90.0%'), findsOneWidget);
    final goalText = tester.widget<Text>(find.text('0 / 10 প্রশ্ন'));
    expect(goalText.style?.color, AppTheme.darkTheme.colorScheme.primary);
    final accuracy = tester.widget<Text>(find.text('90.0%'));
    expect(accuracy.style?.color, AppTheme.darkTheme.colorScheme.onSurface);
    final goalCard = tester.widget<Card>(
      find.ancestor(of: find.text('0 / 10 প্রশ্ন'), matching: find.byType(Card)).first,
    );
    expect(goalCard.color, isNull); // Uses the global dark card theme.
    await tester.scrollUntilVisible(find.text('আপনার অর্জন'), 250,
      scrollable: find.byType(Scrollable).first);
    expect(find.text('প্রথম পদক্ষেপ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Light English dashboard localizes labels and supports large text', (tester) async {
    await _mount(tester, mode: ThemeMode.light, language: 'en', scale: 1.5);
    expect(find.text('Practice Dashboard'), findsOneWidget);
    expect(find.text('Today’s goal'), findsOneWidget);
    final goal = tester.widget<Text>(find.text('0 / 10 questions'));
    expect(goal.style?.color, AppTheme.lightTheme.colorScheme.primary);
    await tester.scrollUntilVisible(find.text('Subject performance'), 250,
      scrollable: find.byType(Scrollable).first);
    expect(find.text('Fire'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty history and invalid zero target show safe empty states', (tester) async {
    await _mount(tester, mode: ThemeMode.dark, language: 'en',
      data: const {'daily_target': 0});
    expect(find.text('0 / 10 questions'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No practice recorded yet.'), 200,
      scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
}
