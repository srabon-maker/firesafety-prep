import 'package:fire_safety_job_prep/screens/settings_page.dart';
import 'package:fire_safety_job_prep/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final settings = AppSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await settings.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await settings.load();
  });

  Future<void> mount(WidgetTester tester, {double scale = 1, double width = 360}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: settings.locale,
      builder: (_, locale, __) => ValueListenableBuilder<ThemeMode>(
        valueListenable: settings.themeMode,
        builder: (_, mode, __) => MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('bn'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const SettingsPage(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Compact settings preserves language and theme persistence', (tester) async {
    await mount(tester);
    expect(find.text('সেটিংস'), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(settings.locale.value.languageCode, 'en');

    for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
      await tester.tap(find.byKey(ValueKey('settings-theme-${mode.name}')));
      await tester.pumpAndSettle();
      expect(settings.themeMode.value, mode);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_theme_mode'), mode.name);
    }
    expect((await SharedPreferences.getInstance()).getString('app_locale'), 'en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings fits narrow screens and enlarged text', (tester) async {
    await settings.setTheme(ThemeMode.dark);
    await mount(tester, scale: 1.8, width: 300);
    expect(find.byKey(const ValueKey('settings-language-selector')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('settings-theme-light')));
    await tester.tap(find.byKey(const ValueKey('settings-theme-light')));
    await tester.pumpAndSettle();
    expect(settings.themeMode.value, ThemeMode.light);
    expect(tester.takeException(), isNull);
  });
}
