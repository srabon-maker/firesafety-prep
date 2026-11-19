import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ModelTestService {
  ModelTestService._();
  static final instance = ModelTestService._();
  static const _base = 'https://fire.manobikishwarganj.com/api/tests.php';
  static const _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> _request(String action, {Map<String, dynamic>? body, bool auth = false}) async {
    final uri = Uri.parse('$_base?action=$action');
    final headers = <String, String>{'Accept':'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = await AuthService.instance.getSessionToken();
      if (token == null || token.isEmpty) throw Exception('পরীক্ষা দিতে লগইন করুন।');
      headers['Authorization'] = 'Bearer $token';
    }
    final response = body == null
      ? await http.get(uri, headers: headers).timeout(_timeout)
      : await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(_timeout);
    Map<String,dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String,dynamic>) throw const FormatException();
      data = decoded;
    } catch (_) { throw Exception('সার্ভারের উত্তর সঠিক নয়।'); }
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw Exception(data['message']?.toString() ?? 'অনুরোধ সম্পন্ন হয়নি।');
    }
    return data;
  }

  Future<List<Map<String,dynamic>>> listTests() async {
    final data = await _request('list');
    return (data['data'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  Future<List<Map<String,dynamic>>> activeAttempts() async {
    final data = await _request('active_attempts', auth: true);
    return (data['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String,dynamic>> start(int testId) async =>
      Map<String,dynamic>.from((await _request('start',body:{'test_id':testId},auth:true))['attempt'] as Map);
  Future<void> saveAnswer({required int attemptId,required int testId,required int questionId,required String answer}) async {
    await _request('answer',body:{'test_id':testId,'attempt_id':attemptId,'question_id':questionId,'answer':answer},auth:true);
  }
  Future<Map<String,dynamic>> submit({required int attemptId,required int testId}) async =>
      _request('submit',body:{'test_id':testId,'attempt_id':attemptId},auth:true);
  Future<Map<String,dynamic>> getResult(int attemptId) async =>
      Map<String,dynamic>.from((await _request('result&attempt_id=$attemptId',auth:true))['result'] as Map);

  Future<List<Map<String,dynamic>>> myResults() async {
    final data=await _request('my_results',auth:true);
    return (data['data'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
}
