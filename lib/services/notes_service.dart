import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/study_note.dart';
import 'auth_service.dart';

class NotesLoadException implements Exception {
  const NotesLoadException(this.code, this.bn, this.en);
  final String code, bn, en;
  String message({bool english = false}) => '${english ? en : bn} ($code)';
  @override
  String toString() => message();
}

class NotesService {
  NotesService._() : _client = null, _readToken = AuthService.instance.getSessionToken,
      _retryDelay = const Duration(milliseconds: 500);
  NotesService.withClient(http.Client client, Future<String?> Function() readToken,
      {Duration retryDelay = Duration.zero})
      : _client = client, _readToken = readToken, _retryDelay = retryDelay;
  final http.Client? _client;
  final Future<String?> Function() _readToken;
  final Duration _retryDelay;
  static final NotesService instance = NotesService._();

  static const endpoint =
      'https://fire.manobikishwarganj.com/api/notes.php';
  static const timeout = Duration(seconds: 15);

  static const _sessionChanged = NotesLoadException('SESSION_CHANGED',
      'সেশন পরিবর্তিত হয়েছে। আবার চেষ্টা করুন।', 'Session changed. Please try again.');
  static const _networkError = NotesLoadException('NETWORK',
      'ইন্টারনেট সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।', 'Check your connection and try again.');
  static const _timeoutError = NotesLoadException('TIMEOUT',
      'সার্ভার উত্তর দিতে দেরি করছে। আবার চেষ্টা করুন।', 'The server took too long to respond. Try again.');

  Future<Map<String, dynamic>> _getRead(Uri uri) async {
    final token = await _readToken();
    final headers = {'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'};
    for (var attempt = 0; attempt < 2; attempt++) {
      if (await _readToken() != token) throw _sessionChanged;
      try {
        final client = _client;
        final response = await (client == null
            ? http.get(uri, headers: headers)
            : client.get(uri, headers: headers)).timeout(timeout);
        if (await _readToken() != token) throw _sessionChanged;
        final status = response.statusCode;
        if (attempt == 0 && const {502, 503, 504}.contains(status)) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        if (status == 401 || status == 403) {
          throw NotesLoadException('HTTP_$status', 'লগইন বা সদস্যপদ যাচাই করুন।',
              'Check your login or membership.');
        }
        if (status >= 500) {
          throw NotesLoadException('HTTP_$status', 'নোট সার্ভারে সমস্যা হচ্ছে। পরে আবার চেষ্টা করুন।',
              'The notes server has a problem. Try again later.');
        }
        if (status != 200) {
          throw NotesLoadException('HTTP_$status', 'নোটের অনুরোধ সফল হয়নি।',
              'The notes request was unsuccessful.');
        }
        Map<String, dynamic> data;
        try {
          data = _decode(response);
        } on FormatException {
          throw const NotesLoadException('INVALID_RESPONSE', 'নোট সার্ভারের উত্তর সঠিক নয়।',
              'The notes server returned an invalid response.');
        }
        if (data['success'] != true) {
          throw const NotesLoadException('API_ERROR', 'নোট সার্ভার অনুরোধ সম্পন্ন করতে পারেনি।',
              'The notes server could not complete the request.');
        }
        return data;
      } on TimeoutException {
        if (attempt == 1) throw _timeoutError;
      } on http.ClientException {
        if (attempt == 1) throw _networkError;
      }
      await Future<void>.delayed(_retryDelay);
    }
    throw _networkError;
  }

  Future<StudyNotesPage> fetchNotes({
    String search = '',
    int? categoryId,
    int page = 1,
    bool summaryOnly = false,
  }) async {
    final query = <String, String>{'page': page.toString(),'premium_preview':'1', if (summaryOnly) 'summary_only':'1'};
    if (search.trim().isNotEmpty) query['search'] = search.trim();
    if (categoryId != null) query['category'] = categoryId.toString();

    final uri = Uri.parse(endpoint).replace(queryParameters: query);
    final decoded = await _getRead(uri);
    return StudyNotesPage.fromJson(decoded);
  }

  Future<StudyNote> fetchNote(int id) async {
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {'action': 'detail', 'id': id.toString(),'premium_preview':'1'},
    );
    final decoded = await _getRead(uri);
    final data = decoded['data'];
    if (data is! Map) {
      throw const FormatException('নোটের বিস্তারিত তথ্য সঠিক নয়।');
    }
    return StudyNote.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Uri> privatePdfLink(int id) async{
    final token=await AuthService.instance.getSessionToken();
    if(token==null||token.isEmpty)throw const FormatException('লগইন প্রয়োজন।');
    final response=await http.post(Uri.parse('https://fire.manobikishwarganj.com/api/premium_pdf/index.php'),
      headers:{'Accept':'application/json','Content-Type':'application/json','Authorization':'Bearer $token'},
      body:jsonEncode({'note_id':id})).timeout(timeout);
    if(await AuthService.instance.getSessionToken()!=token)throw const FormatException('সেশন পরিবর্তিত হয়েছে।');
    final data=_decode(response);
    if(response.statusCode!=200||data['success']!=true)throw const FormatException('PDF পাওয়া যায়নি। Premium সদস্যপদ পরীক্ষা করুন।');
    final uri=Uri.tryParse(data['url']?.toString()??'');
    if(uri==null||uri.scheme!='https'||uri.host!='fire.manobikishwarganj.com'||uri.hasPort||uri.userInfo.isNotEmpty||uri.hasFragment||uri.path!='/api/premium_pdf/index.php'||uri.queryParameters.length!=1||!RegExp(r'^[a-f0-9]{64}$').hasMatch(uri.queryParameters['download']??'')) {
      throw const FormatException('Invalid PDF link');
    }
    return uri;
  }
  Map<String, dynamic> _decode(http.Response response) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const FormatException('সার্ভারের response সঠিক JSON নয়।');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('সার্ভারের response format সঠিক নয়।');
    }
    return decoded;
  }
}
