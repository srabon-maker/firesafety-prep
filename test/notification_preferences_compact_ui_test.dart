import 'package:fire_safety_job_prep/screens/notification_preferences_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> mount(WidgetTester tester, Brightness brightness, String language) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: brightness),
      locale: Locale(language),
      supportedLocales: const [Locale('bn'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const NotificationPreferencesPage(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Compact header and all three preferences in dark Bengali mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await mount(tester, Brightness.dark, 'bn');
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(find.text('নোটিফিকেশন পছন্দ'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(3));
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('পছন্দ ডিভাইসে সংরক্ষিত হয়। Push Notification এখনো সক্রিয় নয়।'), findsOneWidget);
    final keys = {
      'study': 'notify_study_reminders',
      'updates': 'notify_app_updates',
      'community': 'notify_community_activity',
    };
    for (final entry in keys.entries) {
      final tile = find.byKey(ValueKey('notification-preference-${entry.key}'));
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect((await SharedPreferences.getInstance()).getBool(entry.value), isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Light English mode loads saved preferences', (tester) async {
    SharedPreferences.setMockInitialValues({'notify_app_updates': false});
    await mount(tester, Brightness.light, 'en');
    expect(find.text('Notification preferences'), findsOneWidget);
    expect(find.text('Preferences are saved on this device. Push notifications are not active yet.'), findsOneWidget);
    final tile = find.byKey(const ValueKey('notification-preference-updates'));
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getBool('notify_app_updates'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
