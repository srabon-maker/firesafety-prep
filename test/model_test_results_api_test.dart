import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fire_safety_job_prep/services/model_test_service.dart';

ModelTestService service(http.Response Function(http.Request) reply) =>
    ModelTestService(currentToken: () async => 'test-token',
      client: MockClient((request) async => reply(request)));

http.Response jsonReply(Map<String, dynamic> data, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), status,
      headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('my results use current bearer session and preserve UTF-8 and numeric strings', () async {
    final api = service((request) {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/tests.php');
      expect(request.url.queryParameters, {'action': 'my_results'});
      expect(request.headers['Authorization'], 'Bearer test-token');
      return jsonReply({'success': true, 'data': [
        {'attempt_id': '1', 'title': 'বাংলা পরীক্ষা', 'score': '8.00',
          'total_marks': '10.00', 'passed': '1'},
      ]}, 200);
    });
    final rows = await api.myResults();
    expect(rows.single['title'], 'বাংলা পরীক্ষা');
    expect(rows.single['score'], '8.00');
  });

  test('empty results differ from malformed success data', () async {
    expect(await service((_) => jsonReply({'success': true, 'data': []}, 200)).myResults(), isEmpty);
    for (final data in [null, {}, [null]]) {
      await expectLater(service((_) => jsonReply({'success': true, 'data': data}, 200)).myResults(),
        throwsA(isA<ModelTestRequestException>().having((e) => e.code, 'code', 'INVALID_RESPONSE')));
    }
  });

  test('schema failure stays an error instead of pretending there are no results', () async {
    final api = service((_) => jsonReply({
      'success': false, 'code': 'MODEL_TEST_MIGRATION_REQUIRED',
      'message': 'ডেটাবেজ আপডেট প্রয়োজন।',
    }, 503));
    await expectLater(api.myResults(), throwsA(isA<ModelTestRequestException>()
      .having((e) => e.code, 'code', 'MODEL_TEST_MIGRATION_REQUIRED')
      .having((e) => e.status, 'status', 503)));
  });

  test('expired login, missing endpoint and server error are distinguishable', () async {
    for (final status in [401, 404, 500]) {
      final api = service((_) => status == 500
          ? jsonReply({'success': false}, status)
          : http.Response('not JSON', status));
      await expectLater(api.myResults(), throwsA(isA<ModelTestRequestException>()
        .having((e) => e.code, 'code', {401:'AUTH_REQUIRED',404:'ENDPOINT_NOT_FOUND',500:'SERVER_ERROR'}[status])));
    }
  });

  test('network failure and account change cannot return another session result', () async {
    final network = ModelTestService(currentToken: () async => 'test-token',
      client: MockClient((_) async => throw http.ClientException('offline')));
    await expectLater(network.myResults(), throwsA(isA<ModelTestRequestException>()
      .having((e) => e.code, 'code', 'NETWORK')));
    var token = 'first';
    final switched = ModelTestService(currentToken: () async => token,
      client: MockClient((_) async {
        token = 'second';
        return jsonReply({'success': true, 'data': []}, 200);
      }));
    await expectLater(switched.myResults(), throwsA(isA<ModelTestRequestException>()
      .having((e) => e.code, 'code', 'SESSION_CHANGED')));
  });
}
