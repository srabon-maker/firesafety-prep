import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/profile_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

Future<void> mountProfile(WidgetTester tester, ThemeMode mode, String language,
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
    home: ProfilePage(
      onLogout: () {},
      loadProfile: (_) async => {
        'full_name': 'Sample User', 'email': 'sample@example.com',
        'mobile_number': '01000000000', 'current_status': 'Employed',
        'company_name': 'Example Company', 'designation': 'Safety Officer',
        'job_location': 'Dhaka', 'current_address': 'Sample address',
      },
      loadStats: () async => [<dynamic>[], {'overall': {'questions': 10, 'correct': 9}}],
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Dark Bengali profile uses compact header and removes career shortcut', (tester) async {
    await mountProfile(tester, ThemeMode.dark, 'bn');
    expect(find.text('প্রোফাইল'), findsOneWidget);
    expect(tester.widget<Text>(find.text('প্রোফাইল')).style?.fontSize, 15.5);
    expect(find.text('ক্যারিয়ার ডেভেলপমেন্ট'), findsNothing);
    expect(find.text('দৈনিক লক্ষ্য ও শেখার অগ্রগতি'), findsNothing);
    expect(find.text('অনুশীলন ড্যাশবোর্ড'), findsOneWidget);
    final menuIcon = tester.widget<Icon>(find.byIcon(Icons.insights_rounded));
    expect(menuIcon.color, AppTheme.darkTheme.colorScheme.primary);
    await tester.ensureVisible(find.text('অ্যাকাউন্ট ও নিরাপত্তা'));
    await tester.pumpAndSettle();
    expect(find.text('প্রিমিয়াম সদস্যপদ'), findsOneWidget);
    expect(find.text('নোটিফিকেশন ইনবক্স'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Personal information uses compact spacing without losing any fields', (tester) async {
    await mountProfile(tester, ThemeMode.dark, 'en');
    expect(find.text('Personal information'), findsNothing);
    expect(find.byKey(const ValueKey('profile-personal-card')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-summary-card')));
    await tester.pumpAndSettle();
    final heading = find.text('Personal information');
    expect(heading, findsOneWidget);
    expect(tester.widget<Text>(heading).style?.fontSize, 15.5);
    expect(find.text('Profile'), findsNothing);
    final card = find.byKey(const ValueKey('profile-personal-card'));
    final labels = <String, String>{
      'Full name': 'Sample User', 'Email': 'sample@example.com',
      'Mobile': '01000000000', 'Current status': 'Employed',
      'Company': 'Example Company', 'Designation': 'Safety Officer',
      'Job location': 'Dhaka', 'Current address': 'Sample address',
    };
    for (final entry in labels.entries) {
      final row = find.byKey(ValueKey('profile-info-${entry.key}'));
      expect(row, findsOneWidget);
      final label = find.descendant(of: row, matching: find.text(entry.key));
      final value = find.descendant(of: row, matching: find.text(entry.value));
      expect(label, findsOneWidget);
      expect(value, findsOneWidget);
      expect(tester.widget<Padding>(row).padding, const EdgeInsets.symmetric(vertical: 4));
      expect(tester.widget<Text>(label).style?.fontSize, 11);
      expect(tester.widget<Text>(value).style?.fontSize, 14);
      expect(tester.getTopLeft(value).dy - tester.getBottomLeft(label).dy, closeTo(2, .1));
    }
    final edit = find.descendant(of: card, matching: find.byType(OutlinedButton));
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    expect(edit.hitTestable(), findsOneWidget);
    expect(tester.getSize(edit).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Light English profile preserves menu entries and personal info at large text', (tester) async {
    await mountProfile(tester, ThemeMode.light, 'en', scale: 1.5);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Career development'), findsNothing);
    expect(find.text('Model test results'), findsOneWidget);
    expect(find.text('Saved notes'), findsOneWidget);
    expect(find.text('App settings'), findsOneWidget);
    expect(find.text('Notification preferences'), findsOneWidget);
    expect(find.text('Personal information'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('profile-summary-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-summary-card')));
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Edit information'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit information'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Personal information'), findsNothing);
    await tester.ensureVisible(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Account security is compact and retains delete confirmation', (tester) async {
    await mountProfile(tester, ThemeMode.dark, 'en');
    final entry = find.text('Account & security');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('Deleting your account cannot be undone.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-delete-tile')));
    // The account page intentionally shows an indeterminate progress bar
    // while the confirmation dialog is open; do not wait for global settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Permanently delete account?'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, 'Delete permanently');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Permanently delete account?'), findsNothing);
    expect(find.byKey(const ValueKey('account-delete-tile')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
