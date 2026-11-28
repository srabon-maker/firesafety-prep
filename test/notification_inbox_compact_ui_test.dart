import 'dart:convert';
import 'package:fire_safety_job_prep/screens/notification_inbox_page.dart';
import 'package:fire_safety_job_prep/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Future<void> mount(WidgetTester tester, MockClient client, Brightness brightness) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: NotificationInboxPage(createService: () async =>
        NotificationService('test', client: client, currentToken: () async => 'test')),
    ));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('Empty inbox uses compact header in ${brightness.name}', (tester) async {
      await mount(tester, MockClient((_) async =>
        http.Response('{"success":true,"data":[],"unread_count":0}', 200)), brightness);
      expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('0 unread'), findsOneWidget);
      expect(find.text('No notifications'), findsOneWidget);
      final markAll = tester.widget<InkWell>(find.byKey(const ValueKey('inbox-mark-all')));
      expect(markAll.onTap, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Mark all retains server read count and disables action', (tester) async {
    var marked = false;
    await mount(tester, MockClient((request) async {
      if (request.method == 'POST') {
        expect(jsonDecode(request.body), {'action': 'mark_all_read', 'through_id': '42'});
        marked = true;
        return http.Response('{"success":true,"unread_count":0}', 200);
      }
      return http.Response(jsonEncode({
        'success': true, 'unread_count': 1, 'data': [{
          'id': '42', 'title': 'Test update', 'message': 'A new update',
          'notification_type': 'study', 'is_read': false, 'sent_at': '2026-11-28',
        }],
      }), 200);
    }), Brightness.dark);
    expect(find.text('1 unread'), findsOneWidget);
    expect(find.text('Test update'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inbox-mark-all')));
    await tester.pumpAndSettle();
    expect(marked, isTrue);
    expect(find.text('0 unread'), findsOneWidget);
    expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);
    expect(tester.widget<InkWell>(find.byKey(const ValueKey('inbox-mark-all'))).onTap, isNull);
  });

  testWidgets('Expired session is not displayed as an empty inbox', (tester) async {
    await mount(tester, MockClient((_) async => http.Response('{}', 401)), Brightness.light);
    expect(find.text('Session expired. Go back and sign in again.'), findsOneWidget);
    expect(find.text('No notifications'), findsNothing);
    expect(find.byKey(const ValueKey('inbox-unread-count')), findsNothing);
  });
}
