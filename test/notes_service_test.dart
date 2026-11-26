import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fire_safety_job_prep/services/notes_service.dart';

http.Response notes() => http.Response(jsonEncode({
  'success': true,
  'data': [{'id': 1, 'title': 'Fire safety', 'locked': true}],
  'categories': [],
  'pagination': {'page': 1, 'total_pages': 1, 'total': 1}
}), 200);

void main() {
  test('preview retries transient failure, sends same session and preserves locked flag', () async {
    var calls = 0;
    final client = MockClient((request) async {
      expect(request.url.queryParameters['premium_preview'], '1');
      expect(request.url.queryParameters['summary_only'], '1');
      expect(request.headers['authorization'], 'Bearer test-token');
      return ++calls == 1 ? http.Response('Unavailable', 503) : notes();
    });
    final result = await NotesService.withClient(client, () async => 'test-token')
        .fetchNotes(summaryOnly: true);
    expect(calls, 2);
    expect(result.notes.single.locked, isTrue);
    expect(result.notes.single.content, isNull);
  });
  test('server failure is not treated as an empty successful list', () async {
    final client = MockClient((_) async => http.Response('Server error', 500));
    await expectLater(NotesService.withClient(client, () async => null).fetchNotes(),
      throwsA(isA<NotesLoadException>().having((e) => e.code, 'code', 'HTTP_500')));
  });
  test('unauthorized response does not retry anonymously', () async {
    var calls = 0;
    final client = MockClient((_) async { calls++; return http.Response('', 401); });
    await expectLater(NotesService.withClient(client, () async => 'token').fetchNotes(),
      throwsA(isA<NotesLoadException>().having((e) => e.code, 'code', 'HTTP_401')));
    expect(calls, 1);
  });
  test('response from a previous session is discarded', () async {
    String? token = 'old';
    final client = MockClient((_) async { token = 'new'; return notes(); });
    await expectLater(NotesService.withClient(client, () async => token).fetchNotes(),
      throwsA(isA<NotesLoadException>().having((e) => e.code, 'code', 'SESSION_CHANGED')));
  });
}
