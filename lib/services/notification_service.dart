import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/inbox_notification.dart';
import 'auth_service.dart';

class InboxSessionExpired implements Exception {
  const InboxSessionExpired();
}

/// Bound to a single login session, with no shared notification cache.
class NotificationService {
  NotificationService(this._token, {http.Client? client,
      Future<String?> Function()? currentToken})
      : _client = client ?? http.Client(),
        _currentToken = currentToken ?? AuthService.instance.getSessionToken;

  static const _url = 'https://fire.manobikishwarganj.com/api/notifications/index.php';
  final String _token;
  final http.Client _client;
  final Future<String?> Function() _currentToken;

  Future<void> checkSession() async {
    if (_token.isEmpty || await _currentToken() != _token) {
      throw const InboxSessionExpired();
    }
  }

  Future<Map<String, dynamic>> _request({String? beforeId,
      Map<String, String>? body}) async {
    await checkSession();
    final uri = Uri.parse(_url).replace(queryParameters:
        beforeId == null ? null : {'before_id': beforeId});
    final headers = {'Accept': 'application/json', 'Authorization': 'Bearer $_token'};
    final response = await (body == null
        ? _client.get(uri, headers: headers)
        : _client.post(uri, headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body))).timeout(const Duration(seconds: 20));
    await checkSession();
    if (response.statusCode == 401) throw const InboxSessionExpired();
    if (response.statusCode != 200) throw const FormatException('Inbox request failed');
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> || data['success'] != true) {
      throw const FormatException('Invalid inbox response');
    }
    return data;
  }

  Future<InboxPageResult> fetch({String? beforeId}) async =>
      InboxPageResult.fromJson(await _request(beforeId: beforeId));

  Future<int> markRead(String id) async => InboxPageResult.parseUnread(
      await _request(body: {'action': 'mark_read', 'id': id}));

  Future<int> markAllRead(String throughId) async => InboxPageResult.parseUnread(
      await _request(body: {'action': 'mark_all_read', 'through_id': throughId}));

  void dispose() => _client.close();
}
