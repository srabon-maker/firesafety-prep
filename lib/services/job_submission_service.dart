import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class JobSubmissionService {
  JobSubmissionService._();
  static final JobSubmissionService instance = JobSubmissionService._();

  static const _base = 'https://fire.manobikishwarganj.com/api/jobs/';
  static const _timeout = Duration(seconds: 25);

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.instance.getSessionToken();
    if (token == null || token.isEmpty) {
      throw Exception('সার্কুলার জমা দিতে লগইন করুন।');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      throw const FormatException('সার্ভার থেকে সঠিক উত্তর পাওয়া যায়নি।');
    }
    if (body is! Map<String, dynamic>) {
      throw const FormatException('সার্ভারের উত্তর সঠিক নয়।');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'অনুরোধটি সম্পন্ন হয়নি।');
    }
    return body;
  }

  Future<void> submit(Map<String, dynamic> payload) async {
    final response = await http
        .post(
          Uri.parse('${_base}submit.php'),
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    _decode(response);
  }

  Future<List<Map<String, dynamic>>> mySubmissions() async {
    final response = await http
        .get(Uri.parse('${_base}my_submissions.php'), headers: await _headers())
        .timeout(_timeout);
    final data = _decode(response)['data'];
    if (data is! List) {
      throw const FormatException('সার্কুলারের তালিকা সঠিক নয়।');
    }
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
