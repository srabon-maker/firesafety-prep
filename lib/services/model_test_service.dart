
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ModelTestService {
  ModelTestService._();

  static final ModelTestService instance = ModelTestService._();

  // API Configuration
  static const String _baseUrl =
      'https://fire.manobikishwarganj.com/api/tests.php';

  static const Duration _requestTimeout =
      Duration(seconds: 20);

  // --------------------------------------------------
  // COMMON API REQUEST HANDLER
  // --------------------------------------------------

  Future<Map<String, dynamic>> _request(
    String action, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool auth = false,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'action': action,
        ...?queryParameters,
      },
    );

    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    // Authentication
    if (auth) {
      final token =
          await AuthService.instance.getSessionToken();

      if (token == null || token.isEmpty) {
        throw Exception('পরীক্ষা দিতে লগইন করুন।');
      }

      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = body == null
          ? await http
              .get(uri, headers: headers)
              .timeout(_requestTimeout)
          : await http
              .post(
                uri,
                headers: headers,
                body: jsonEncode(body),
              )
              .timeout(_requestTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception(
        'সার্ভার থেকে Response পেতে দেরি হচ্ছে। আবার চেষ্টা করুন।',
      );
    } on http.ClientException {
      throw Exception(
        'ইন্টারনেট সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।',
      );
    }
  }

  // --------------------------------------------------
  // API RESPONSE HANDLER
  // --------------------------------------------------

  Map<String, dynamic> _handleResponse(
    http.Response response,
  ) {
    Map<String, dynamic> data;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const FormatException();
      }

      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw Exception(
        'সার্ভার থেকে সঠিক JSON Response পাওয়া যায়নি।',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data['message']?.toString() ??
            'সার্ভার Error: ${response.statusCode}',
      );
    }

    if (data['success'] != true) {
      throw Exception(
        data['message']?.toString() ??
            'অনুরোধটি সম্পন্ন করা যায়নি।',
      );
    }

    return data;
  }

  // --------------------------------------------------
  // SAFE DATA CONVERSION
  // --------------------------------------------------

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is! Map) {
      throw Exception('সার্ভারের Data সঠিক নয়।');
    }

    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _toList(dynamic value) {
    if (value == null) return [];

    if (value is! List) {
      throw Exception('সার্ভারের List Data সঠিক নয়।');
    }

    return value.map((item) => _toMap(item)).toList();
  }

  // --------------------------------------------------
  // 1. GET ALL AVAILABLE TESTS
  // --------------------------------------------------

  Future<List<Map<String, dynamic>>> listTests() async {
    final data = await _request('list');

    return _toList(data['data']);
  }

  // --------------------------------------------------
  // 2. GET PRACTICE QUESTIONS
  // --------------------------------------------------

  Future<List<Map<String, dynamic>>> practiceQuestions({
    required String category,
    String difficulty = 'all',
    int limit = 15,
  }) async {
    if (category.trim().isEmpty) {
      throw Exception('একটি Category নির্বাচন করুন।');
    }

    if (limit < 1) {
      throw Exception('প্রশ্নের সংখ্যা সঠিক নয়।');
    }

    final data = await _request(
      'practice_questions',
      queryParameters: {
        'category': category.trim(),
        'difficulty': difficulty,
        'limit': limit.toString(),
      },
      auth: true,
    );

    return _toList(data['data']);
  }

  // --------------------------------------------------
  // 3. PRACTICE DASHBOARD
  // --------------------------------------------------

  Future<Map<String, dynamic>> practiceDashboard() async {
    final data = await _request(
      'practice_dashboard',
      auth: true,
    );

    return _toMap(data['data']);
  }

  // --------------------------------------------------
  // 4. UPDATE DAILY PRACTICE TARGET
  // --------------------------------------------------

  Future<void> updatePracticeTarget(
    int dailyTarget,
  ) async {
    if (dailyTarget < 1) {
      throw Exception(
        'দৈনিক অনুশীলনের Target কমপক্ষে ১ হতে হবে।',
      );
    }

    await _request(
      'practice_target',
      body: {
        'daily_target': dailyTarget,
      },
      auth: true,
    );
  }

  // --------------------------------------------------
  // 5. SAVE PRACTICE SESSION
  // --------------------------------------------------

  Future<void> savePracticeSession({
    required String category,
    required String difficulty,
    required int totalQuestions,
    required int correctCount,
  }) async {
    if (category.trim().isEmpty) {
      throw Exception('Category পাওয়া যায়নি।');
    }

    if (totalQuestions < 1 ||
        correctCount < 0 ||
        correctCount > totalQuestions) {
      throw Exception('Practice Result সঠিক নয়।');
    }

    await _request(
      'practice_complete',
      body: {
        'category': category,
        'difficulty': difficulty,
        'total_questions': totalQuestions,
        'correct_count': correctCount,
      },
      auth: true,
    );
  }

  // --------------------------------------------------
  // 6. GET ACTIVE TEST ATTEMPTS
  // --------------------------------------------------

  Future<List<Map<String, dynamic>>> activeAttempts() async {
    final data = await _request(
      'active_attempts',
      auth: true,
    );

    return _toList(data['data']);
  }

  // --------------------------------------------------
  // 7. START NEW MODEL TEST
  // --------------------------------------------------

  Future<Map<String, dynamic>> start(
    int testId,
  ) async {
    if (testId < 1) {
      throw Exception('Test ID সঠিক নয়।');
    }

    final data = await _request(
      'start',
      body: {
        'test_id': testId,
      },
      auth: true,
    );

    return _toMap(data['attempt']);
  }

  // --------------------------------------------------
  // 8. SAVE TEST ANSWER
  // --------------------------------------------------

  Future<void> saveAnswer({
    required int attemptId,
    required int testId,
    required int questionId,
    required String answer,
  }) async {
    if (attemptId < 1 ||
        testId < 1 ||
        questionId < 1) {
      throw Exception('Test Information সঠিক নয়।');
    }

    await _request(
      'answer',
      body: {
        'test_id': testId,
        'attempt_id': attemptId,
        'question_id': questionId,
        'answer': answer,
      },
      auth: true,
    );
  }

  // --------------------------------------------------
  // 9. SUBMIT MODEL TEST
  // --------------------------------------------------

  Future<Map<String, dynamic>> submit({
    required int attemptId,
    required int testId,
  }) async {
    if (attemptId < 1 || testId < 1) {
      throw Exception('Test Information সঠিক নয়।');
    }

    return await _request(
      'submit',
      body: {
        'test_id': testId,
        'attempt_id': attemptId,
      },
      auth: true,
    );
  }

  // --------------------------------------------------
  // 10. GET TEST RESULT
  // --------------------------------------------------

  Future<Map<String, dynamic>> getResult(
    int attemptId,
  ) async {
    if (attemptId < 1) {
      throw Exception('Attempt ID সঠিক নয়।');
    }

    final data = await _request(
      'result',
      queryParameters: {
        'attempt_id': attemptId.toString(),
      },
      auth: true,
    );

    return _toMap(data['result']);
  }

  // --------------------------------------------------
  // 11. GET MY TEST RESULTS
  // --------------------------------------------------

  Future<List<Map<String, dynamic>>> myResults() async {
    final data = await _request(
      'my_results',
      auth: true,
    );

    return _toList(data['data']);
  }
}
