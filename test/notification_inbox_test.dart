import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/models/inbox_notification.dart';
import '../lib/services/notification_service.dart';

Map<String, dynamic> item() => {
  'id': '9007199254740993', 'title': 'পরীক্ষা', 'message': 'বার্তা',
  'notification_type': 'study', 'is_read': false,
  'sent_at': '2026-11-25 10:00:00',
};

void main() {
  test('notification IDs are preserved and read copy is immutable', () {
    final n = InboxNotification.fromJson(item());
    expect(n.id, '9007199254740993');
    expect(n.read().isRead, true);
    expect(n.isRead, false);
    expect(() => InboxNotification.fromJson({...item(), 'is_read': 1}),
        throwsFormatException);
  });

  test('fetch and read use bearer auth, cursor and expected JSON', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token');
      if (request.method == 'GET') {
        expect(request.url.queryParameters['before_id'], '90');
        return http.Response(jsonEncode({'success': true, 'data': [item()],
          'unread_count': 2, 'next_before_id': '80'}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
      }
      expect(jsonDecode(request.body), {'action': 'mark_all_read', 'through_id': '90'});
      return http.Response('{"success":true,"unread_count":1}', 200);
    });
    final service = NotificationService('token', client: client,
        currentToken: () async => 'token');
    addTearDown(service.dispose);
    final page = await service.fetch(beforeId: '90');
    expect(page.items.single.title, 'পরীক্ষা');
    expect(page.nextBeforeId, '80');
    expect(page.unreadCount, 2);
    expect(await service.markAllRead('90'), 1);
  });

  test('expired session and account changes reject inbox data', () async {
    final service = NotificationService('token',
        client: MockClient((_) async => http.Response('{}', 401)),
        currentToken: () async => 'token');
    addTearDown(service.dispose);
    await expectLater(service.fetch(), throwsA(isA<InboxSessionExpired>()));
    var token = 'token';
    final changed = NotificationService('token',
        client: MockClient((_) async {
          token = 'other';
          return http.Response('{"success":true,"data":[],"unread_count":0}', 200);
        }), currentToken: () async => token);
    addTearDown(changed.dispose);
    await expectLater(changed.fetch(), throwsA(isA<InboxSessionExpired>()));
  });
}
