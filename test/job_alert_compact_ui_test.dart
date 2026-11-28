import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/career_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

Future<void> mountAlerts(WidgetTester tester, ThemeMode mode, String language,
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>?, Map<String, String>) request,
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
    home: CareerSection(section: 'alerts', alertRequest: request),
  ));
  await tester.pumpAndSettle();
}

Map<String, dynamic> response({bool enabled = false, String keyword = '', String location = '', List<Map<String, dynamic>> rows = const []}) =>
    {'preferences': {'enabled': enabled, 'keyword': keyword, 'location': location}, 'data': rows};

void main() {
  testWidgets('Bengali dark alerts retains disclosure in info and empty state', (tester) async {
    await mountAlerts(tester, ThemeMode.dark, 'bn', (action, body, filters) async => response());
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(find.text('চাকরির অ্যালার্ট'), findsNWidgets(2));
    expect(find.text('বর্তমানে বন্ধ'), findsOneWidget);
    expect(find.text('এখনো মিল থাকা চাকরি নেই।'), findsOneWidget);
    await tester.tap(find.byTooltip('অ্যালার্ট সম্পর্কে'));
    await tester.pumpAndSettle();
    expect(find.textContaining('মোবাইল পুশ নয়'), findsOneWidget);
    await tester.tap(find.text('বন্ধ করুন'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('English alert save and check preserve request payloads', (tester) async {
    final calls = <String>[];
    Map<String, dynamic>? saved;
    await mountAlerts(tester, ThemeMode.light, 'en', (action, body, filters) async {
      calls.add(action);
      if (action == 'save_alerts') {
        saved = Map.of(body!);
        return {};
      }
      if (action == 'check_alerts') return {'new_alerts': 1};
      return response(enabled: saved?['enabled'] == true,
        keyword: saved?['keyword']?.toString() ?? '',
        location: saved?['location']?.toString() ?? '',
        rows: const [{'title': 'Safety Officer', 'location': 'Dhaka'}]);
    });
    await tester.tap(find.byType(Switch));
    await tester.enterText(find.byType(TextField).at(0), 'Officer');
    await tester.enterText(find.byType(TextField).at(1), 'Dhaka');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, {'enabled': true, 'keyword': 'Officer', 'location': 'Dhaka'});
    await tester.tap(find.text('Check jobs'));
    await tester.pumpAndSettle();
    expect(calls, ['alerts', 'save_alerts', 'alerts', 'check_alerts', 'alerts']);
    expect(find.text('Safety Officer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text remains usable', (tester) async {
    await mountAlerts(tester, ThemeMode.dark, 'en',
      (action, body, filters) async => response(), scale: 1.6);
    expect(find.byTooltip('About alerts'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
