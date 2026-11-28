import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/career_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

Future<void> mountCourses(WidgetTester tester, String language,
    Future<Map<String, dynamic>> Function(Map<String, String>) loader,
    {double scale = 1, ThemeMode mode = ThemeMode.dark}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme, themeMode: mode,
    locale: Locale(language),
    supportedLocales: const [Locale('bn'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: CareerSection(section: 'courses', loadCourses: loader),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Bengali dark courses keeps disclosure and empty state', (tester) async {
    await mountCourses(tester, 'bn', (filters) async => {'data': []});
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(find.text('প্রশিক্ষণ ও কোর্স'), findsOneWidget);
    expect(find.text('এখনো কোনো কোর্স প্রকাশিত হয়নি।'), findsOneWidget);
    await tester.tap(find.byTooltip('কোর্স সম্পর্কে'));
    await tester.pumpAndSettle();
    expect(find.textContaining('অ্যাপের মাধ্যমে কোর্সে ভর্তি বা পেমেন্ট হয় না'), findsOneWidget);
    await tester.tap(find.text('বন্ধ করুন'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('English courses search and load more preserve cursor and details', (tester) async {
    final calls = <Map<String, String>>[];
    await mountCourses(tester, 'en', (filters) async {
      calls.add(Map.of(filters));
      if (filters['before_id'] == '10') {
        return {'data': [{'title': 'Safety course', 'provider': 'Example Institute',
          'description': 'Full description', 'course_url': 'https://example.com/course'}]};
      }
      return {'data': [{'title': 'Fire training', 'provider': 'Training Center'}],
        'next_before_id': '10'};
    }, mode: ThemeMode.light);
    expect(find.text('1 courses (loaded)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Institute');
    await tester.pumpAndSettle();
    expect(find.text('No matches in loaded courses.'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(calls.last['before_id'], '10');
    expect(find.text('Safety course'), findsOneWidget);
    expect(find.text('Fire training'), findsNothing);
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Full description'), findsOneWidget);
    expect(find.text('Course website'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text and invalid URL remain usable', (tester) async {
    await mountCourses(tester, 'en', (filters) async => {'data': [
      {'title': 'Sample course', 'course_url': 'http://example.com'}
    ]}, scale: 1.6);
    await tester.ensureVisible(find.text('View details'));
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Course website'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
