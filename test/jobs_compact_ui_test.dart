import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/job_circular.dart';
import 'package:fire_safety_job_prep/screens/jobs_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

final jobs = [
  JobCircular(id: 1, organization: 'Sample Company', title: 'Safety Officer',
    publishedAt: DateTime(2026, 1, 1), location: 'Gazipur', isPinned: true),
  JobCircular(id: 2, organization: 'Sample Employer', title: 'Safety Assistant',
    publishedAt: DateTime(2026, 1, 1), location: 'Dhaka'),
  JobCircular(id: 3, organization: 'Example Company', title: 'Archived vacancy',
    publishedAt: DateTime(2020, 1, 1), deadline: DateTime(2020, 1, 2)),
];

Future<void> mountJobs(WidgetTester tester, ThemeMode mode, String language,
    {double scale = 1, List<JobCircular>? data}) async {
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
    home: JobsPage(loadJobs: () async => data ?? jobs),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Dark Bengali jobs page is compact with localized header', (tester) async {
    await mountJobs(tester, ThemeMode.dark, 'bn');
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(tester.widget<Text>(find.text('চাকরির বিজ্ঞপ্তি')).style?.fontSize, 15.5);
    expect(find.text('সার্কুলার জমা দিন'), findsOneWidget);
    expect(find.text('সর্বশেষ প্রকাশিত চাকরির বিজ্ঞপ্তি'), findsNothing);
    expect(find.byTooltip('চাকরির অ্যালার্ট'), findsOneWidget);
    expect(find.byTooltip('রিফ্রেশ'), findsOneWidget);
    expect(find.text('Safety Officer'), findsOneWidget);
    expect(find.text('Archived vacancy'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English filters, pin, reset and search retain existing behavior', (tester) async {
    await mountJobs(tester, ThemeMode.light, 'en');
    expect(find.text('Fire & Safety Jobs'), findsOneWidget);
    expect(find.text('2 listings'), findsOneWidget);
    await tester.tap(find.byTooltip('Pinned only'));
    await tester.pumpAndSettle();
    expect(find.text('Safety Officer'), findsOneWidget);
    expect(find.text('Safety Assistant'), findsNothing);
    await tester.tap(find.byTooltip('Reset filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expired').first);
    await tester.pumpAndSettle();
    expect(find.text('Archived vacancy'), findsOneWidget);
    await tester.tap(find.byTooltip('Reset filters'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Dhaka');
    await tester.pumpAndSettle();
    expect(find.text('Safety Assistant'), findsOneWidget);
    expect(find.text('Safety Officer'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Safety Officer'));
    await tester.pumpAndSettle();
    expect(find.byType(JobCircularDetailsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text and empty data remain usable', (tester) async {
    await mountJobs(tester, ThemeMode.dark, 'en', scale: 1.6, data: []);
    expect(find.text('No jobs found'), findsOneWidget);
    expect(find.byTooltip('Pinned only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
