import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/career_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

Future<void> mountDirectory(WidgetTester tester, String language,
    Future<Map<String, dynamic>> Function(String, Map<String, String>) loader,
    {ThemeMode mode = ThemeMode.dark, double scale = 1,
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? writer}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme, themeMode: mode,
    locale: Locale(language), supportedLocales: const [Locale('bn'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: CareerSection(section: 'directory', directoryRequest: loader,
      directoryWrite: writer ?? (action, body) async => <String, dynamic>{}),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Bengali directory shows compact empty list and consent form', (tester) async {
    await mountDirectory(tester, 'bn', (action, filters) async =>
      action == 'my_profile' ? {'profile': null} : {'data': []});
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(find.text('পেশাজীবী ডিরেক্টরি'), findsOneWidget);
    expect(find.text('এখনো কোনো প্রোফাইল নেই।'), findsOneWidget);
    expect(find.byTooltip('খুঁজুন'), findsOneWidget);
    await tester.tap(find.text('প্রোফাইল যোগ করুন'));
    await tester.pumpAndSettle();
    expect(find.text('প্রোফাইল তৈরি করুন'), findsOneWidget);
    expect(find.text('পেশাজীবী ডিরেক্টরি'), findsNothing);
    await tester.scrollUntilVisible(find.text('জমা দিন'), 150, scrollable: find.byType(Scrollable).first);
    final submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'জমা দিন'));
    expect(submit.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English directory keeps server search and opens full profile', (tester) async {
    final calls = <Map<String, String>>[];
    await mountDirectory(tester, 'en', (action, filters) async {
      if (action == 'my_profile') return {'profile': null};
      calls.add(Map.of(filters));
      return {'data': [
        {'id': 1, 'display_name': 'Sample professional', 'role_name': 'Safety Officer',
          'organization': 'Example Company', 'city': 'Dhaka', 'bio': 'Sample professional summary.'}
      ]};
    }, mode: ThemeMode.light);
    await tester.enterText(find.byType(TextField), 'Safety');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(calls.last['q'], 'Safety');
    await tester.tap(find.text('Sample professional'));
    await tester.pumpAndSettle();
    expect(find.text('Professional profile'), findsOneWidget);
    expect(find.text('Approved profile'), findsOneWidget);
    expect(find.text('Example Company'), findsOneWidget);
    expect(find.text('Dhaka'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sample professional summary.'), 120, scrollable: find.byType(Scrollable).first);
    expect(find.text('Professional summary'), findsOneWidget);
    expect(find.text('Sample professional summary.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Professional Directory'), findsOneWidget);
  });

  testWidgets('Large text and omitted optional details remain accessible', (tester) async {
    await mountDirectory(tester, 'en', (action, filters) async =>
      action == 'my_profile' ? {'profile': null} : {'data': [
        {'id': 2, 'display_name': 'Sample member', 'role_name': 'Officer'}
      ]}, scale: 1.6);
    await tester.tap(find.text('Sample member'));
    await tester.pumpAndSettle();
    expect(find.text('Organization'), findsNothing);
    expect(find.text('Professional summary'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('New profile page saves with consent and returns to directory', (tester) async {
    Map<String, dynamic>? saved;
    final writes = <String>[];
    await mountDirectory(tester, 'en', (action, filters) async =>
      action == 'my_profile'
        ? {'profile': saved == null ? null : {...saved!, 'status': 'pending'}}
        : {'data': []},
      writer: (action, body) async {
        writes.add(action);
        saved = Map.of(body);
        return {'success': true};
      });
    await tester.tap(find.text('Add profile'));
    await tester.pumpAndSettle();
    expect(find.text('Create profile'), findsOneWidget);
    expect(find.text('Search professionals'), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), 'Sample professional');
    await tester.enterText(find.byType(TextField).at(1), 'Safety Officer');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 150,
      scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Submit'));
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit')).onPressed, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(writes, ['save_profile']);
    expect(saved!['consent'], true);
    expect(saved!['display_name'], 'Sample professional');
    expect(saved!['role_name'], 'Safety Officer');
    expect(find.text('Professional Directory'), findsOneWidget);
    expect(find.text('Pending approval'), findsOneWidget);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'Sample professional');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed profile save retains form and permits retry', (tester) async {
    await mountDirectory(tester, 'en', (action, filters) async =>
      action == 'my_profile' ? {'profile': {'display_name': 'Sample member',
        'role_name': 'Officer', 'status': 'approved'}} : {'data': []},
      writer: (action, body) async => throw const FormatException('Sample failure'));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 150,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sample failure'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Submit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
