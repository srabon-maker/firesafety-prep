import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/premium_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

Map<String, dynamic> status({
  bool premium = false,
  String mode = 'free',
  String scheduledMode = 'free',
  String? start,
  String? expiry,
}) => {
  'premium': premium,
  'expires_at': expiry,
  'access_policy': {
    'mode': mode,
    'scheduled_mode': scheduledMode,
    'starts_at': start,
  },
  'plans': [
    {'months': 1, 'proposed_price_bdt': 99},
    {'months': 3, 'proposed_price_bdt': 249},
    {'months': 12, 'proposed_price_bdt': 799},
  ],
};

Future<void> mountPremium(WidgetTester tester, {
  required Future<Map<String, dynamic>> Function() load,
  String language = 'bn',
  ThemeMode theme = ThemeMode.dark,
  double width = 360,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: theme,
    locale: Locale(language),
    supportedLocales: const [Locale('bn'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: PremiumPage(loadStatus: load),
  ));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find.descendant(
    of: find.byType(ListView), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(finder, 150, scrollable: scrollable);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Compact Bengali free page preserves server prices and unavailable purchases', (tester) async {
    await mountPremium(tester, load: () async => status());
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('এখন সব শিক্ষামূলক সুবিধা Free'), findsOneWidget);
    expect(find.text('সুবিধাসমূহ'), findsOneWidget);
    expect(find.byTooltip('পেমেন্ট সহায়তা'), findsOneWidget);
    expect(find.byTooltip('রিফ্রেশ'), findsOneWidget);
    final banner = find.byKey(const ValueKey('premium-status-banner'));
    expect(tester.getSize(banner).height, lessThan(190));
    expect(find.text('এখন কেনা যাবে না'), findsOneWidget);
    for (final months in [1, 3, 12]) {
      final plan = find.byKey(ValueKey('premium-plan-$months'));
      await reveal(tester, plan);
      expect(tester.getSize(plan).height, greaterThanOrEqualTo(64));
      expect(tester.getSize(plan).height, lessThan(110));
      expect(find.descendant(of: plan, matching: find.text('$months মাস')), findsOneWidget);
      final price = {1: 99, 3: 249, 12: 799}[months];
      expect(find.descendant(of: plan, matching: find.text('৳$price')), findsOneWidget);
    }
    await reveal(tester, find.text('পেমেন্ট সংক্রান্ত সহায়তা'));
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Active and scheduled membership states remain distinct and refreshable', (tester) async {
    var calls = 0;
    await mountPremium(tester, language: 'en', theme: ThemeMode.light, load: () async {
      calls++;
      return calls == 1
          ? status(premium: true, mode: 'premium', expiry: '2027-01-01T00:00:00Z')
          : status(scheduledMode: 'premium', start: '2027-02-01T00:00:00Z');
    });
    expect(find.text('Premium membership active'), findsOneWidget);
    expect(find.textContaining('Expires:'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('All learning features are free'), findsOneWidget);
    expect(find.text('Scheduled Premium access restrictions'), findsOneWidget);
    expect(find.text('2027-02-01 06:00 (Bangladesh time)'), findsOneWidget);
    expect(find.textContaining('Expires:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Narrow large text plan cards stay readable and errors can retry', (tester) async {
    var calls = 0;
    await mountPremium(tester, language: 'en', width: 320, scale: 1.6, load: () async {
      if (++calls == 1) throw StateError('offline');
      return status(mode: 'premium');
    });
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Free Membership'), findsOneWidget);
    final plan = find.byKey(const ValueKey('premium-plan-12'));
    await reveal(tester, plan);
    expect(find.descendant(of: plan, matching: find.text('৳799')), findsOneWidget);
    expect(tester.getSize(plan).height, greaterThanOrEqualTo(64));
    expect(tester.takeException(), isNull);
  });
}
