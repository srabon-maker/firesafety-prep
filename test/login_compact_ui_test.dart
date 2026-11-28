import 'package:fire_safety_job_prep/screens/login_page.dart';
import 'package:fire_safety_job_prep/settings/app_settings.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final settings = AppSettings.instance;
  const hintKey = ValueKey('login-registration-hint');
  const buttonKey = ValueKey('login-google-button');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await settings.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await settings.load();
  });

  Future<void> mount(WidgetTester tester,
      {double width = 360, double height = 800, double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
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
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: const LoginPage(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Login follows saved locale and theme without reopening',
      (tester) async {
    await settings.setTheme(ThemeMode.dark);
    await mount(tester);
    expect(find.text('লগইন'), findsOneWidget);
    expect(find.text('স্বাগতম'), findsOneWidget);
    expect(find.text('Google দিয়ে লগইন করুন'), findsOneWidget);
    expect(find.text('নতুনদের লগইনের পর নিবন্ধন করতে হবে।'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('login-brand-logo'))),
        const Size(100, 100));
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 52);
    final hint = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.byKey(hintKey), matching: find.byType(RichText)));
    expect(hint.getBoxesForSelection(const TextSelection(
        baseOffset: 0, extentOffset: 10)).isNotEmpty, isTrue);
    expect(tester.widget<Text>(find.byKey(hintKey)).data, isNot(contains('\n')));
    await settings.setLanguage('en');
    await settings.setTheme(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('New users register after signing in.'), findsOneWidget);
    expect(find.text('স্বাগতম'), findsNothing);
    expect(tester.widget<OutlinedButton>(find.byKey(buttonKey)).onPressed,
        isNotNull);
    expect(Theme.of(tester.element(find.byType(LoginPage))).brightness,
        Brightness.light);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact login stays readable on small screens with large text',
      (tester) async {
    await settings.setLanguage('bn');
    await settings.setTheme(ThemeMode.dark);
    await mount(tester, width: 300, height: 420, scale: 2);
    await tester.ensureVisible(find.byKey(buttonKey));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(buttonKey)).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(find.byKey(hintKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await settings.setLanguage('en');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(buttonKey));
    expect(tester.takeException(), isNull);
  });
}
