import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/study_note.dart';
import 'auth_service.dart';

class NotesService {
  NotesService._();
  static final NotesService instance = NotesService._();

  static const endpoint =
      'https://fire.manobikishwarganj.com/api/notes.php';
  static const timeout = Duration(seconds: 15);

  Future<StudyNotesPage> fetchNotes({
    String search = '',
    int? categoryId,
    int page = 1,
  }) async {
    final query = <String, String>{'page': page.toString(),'premium_preview':'1'};
    if (search.trim().isNotEmpty) query['search'] = search.trim();
    if (categoryId != null) query['category'] = categoryId.toString();

    final uri = Uri.parse(endpoint).replace(queryParameters: query);
    final token=await AuthService.instance.getSessionToken();
    final response = await http.get(uri,headers:{'Accept':'application/json',if(token!=null&&token.isNotEmpty)'Authorization':'Bearer $token'}).timeout(timeout);
    if(await AuthService.instance.getSessionToken()!=token)throw const FormatException('সেশন পরিবর্তিত হয়েছে।');
    final decoded = _decode(response);

    if (response.statusCode != 200 || decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ?? 'নোট লোড করা যায়নি।',
      );
    }
    return StudyNotesPage.fromJson(decoded);
  }

  Future<StudyNote> fetchNote(int id) async {
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {'action': 'detail', 'id': id.toString(),'premium_preview':'1'},
    );
    final token=await AuthService.instance.getSessionToken();
    final response = await http.get(uri,headers:{'Accept':'application/json',if(token!=null&&token.isNotEmpty)'Authorization':'Bearer $token'}).timeout(timeout);
    if(await AuthService.instance.getSessionToken()!=token)throw const FormatException('সেশন পরিবর্তিত হয়েছে।');
    final decoded = _decode(response);

    if (response.statusCode != 200 || decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ?? 'নোটের বিস্তারিত পাওয়া যায়নি।',
      );
    }
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
