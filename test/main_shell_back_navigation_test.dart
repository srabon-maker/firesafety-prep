import 'package:fire_safety_job_prep/screens/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(WidgetTester tester, {bool allowed = true}) async {
    await tester.pumpWidget(MaterialApp(
      home: MainShell(
        authorize: (_) async => allowed,
        tabBuilder: (index, active, onLogout) => Scaffold(
          body: Builder(builder: (context) => Column(children: [
            Text('Tab $index'),
            if (index == 2) const TextField(key: ValueKey('shop-input')),
            TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const Scaffold(
                  body: Text('Detail route'),
                )),
              ),
              child: const Text('Open detail'),
            ),
            TextButton(
              onPressed: () => showDialog<void>(context: context,
                builder: (_) => const AlertDialog(title: Text('Open dialog'))),
              child: const Text('Show dialog'),
            ),
          ])),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, int index) async {
    final bar = find.byType(NavigationBar);
    final destination = find.descendant(
      of: bar, matching: find.byType(NavigationDestination)).at(index);
    await tester.tap(destination);
    await tester.pumpAndSettle();
  }

  int selected(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  testWidgets('Back from every secondary tab returns Home without exit or message',
      (tester) async {
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await mount(tester);
    for (final tab in [1, 2, 3]) {
      await select(tester, tab);
      expect(selected(tester), tab);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(selected(tester), 0);
      expect(exits, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Back closes detail and dialog before changing tab',
      (tester) async {
    await mount(tester);
    await select(tester, 2);
    await tester.tap(find.text('Open detail').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Detail route'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Detail route'), findsNothing);
    expect(selected(tester), 2);
    await tester.tap(find.text('Show dialog').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Open dialog'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open dialog'), findsNothing);
    expect(selected(tester), 2);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selected(tester), 0);
  });

  testWidgets('Back dismisses keyboard first and keeps Shop state on return',
      (tester) async {
    await mount(tester);
    await select(tester, 2);
    final field = find.byKey(const ValueKey('shop-input'));
    await tester.enterText(field, 'Retained search');
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selected(tester), 2);
    expect(tester.testTextInput.isVisible, isFalse);
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selected(tester), 0);
    await select(tester, 2);
    expect(find.text('Retained search'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Protected tabs still require authentication', (tester) async {
    await mount(tester, allowed: false);
    await select(tester, 1);
    expect(selected(tester), 0);
    await select(tester, 3);
    expect(selected(tester), 0);
    await select(tester, 2);
    expect(selected(tester), 2);
  });
}
