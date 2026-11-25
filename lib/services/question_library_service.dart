import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class QuestionLibraryService {
  QuestionLibraryService({Future<String?> Function()? currentToken, http.Client? client})
      : _currentToken = currentToken ?? AuthService.instance.getSessionToken,
        _client = client {
    _session = _currentToken();
  }
  final Future<String?> Function() _currentToken;
  final http.Client? _client;
  late final Future<String?> _session;
  static const endpoint = 'https://fire.manobikishwarganj.com/api/question_library/index.php';

  Future<Map<String,dynamic>> _request({Map<String,String>? query, Map<String,dynamic>? body}) async {
    final token = await _session;
    if (token == null || token.isEmpty || await _currentToken() != token) {
      throw const FormatException('সেশন শেষ হয়েছে। আবার লগইন করুন।');
    }
    final uri=Uri.parse(endpoint).replace(queryParameters:query);
    final headers={'Accept':'application/json','Authorization':'Bearer $token'};
    final response=await (body==null
      ? (_client?.get(uri,headers:headers)??http.get(uri,headers:headers))
      : (_client?.post(uri,headers:{...headers,'Content-Type':'application/json'},body:jsonEncode(body))
        ??http.post(uri,headers:{...headers,'Content-Type':'application/json'},body:jsonEncode(body))))
        .timeout(const Duration(seconds:20));
    if(await _currentToken()!=token || response.statusCode==401) {
      throw const FormatException('সেশন শেষ হয়েছে। আবার লগইন করুন।');
    }
    if(response.statusCode!=200) throw const FormatException('প্রশ্ন ব্যাংকের অনুরোধ সম্পন্ন হয়নি।');
    final data=jsonDecode(utf8.decode(response.bodyBytes));
    if(data is! Map<String,dynamic>||data['success']!=true) throw const FormatException('সঠিক তথ্য পাওয়া যায়নি।');
    return data;
  }
  Future<Map<String,dynamic>> fetch({String search='',String category='',String difficulty='all',
      bool saved=false,int page=1,int? noteId}) => _request(query:{
        'premium_preview':'1','search':search,'category':category,'difficulty':difficulty,
        'saved':saved?'1':'0','page':'$page',if(noteId!=null)'note_id':'$noteId',
      });
  Future<void> bookmark(String id,bool saved) async {
    final result=await _request(body:{'action':'bookmark','id':id,'saved':saved});
    if(result['saved']!=saved) throw const FormatException('বুকমার্ক সংরক্ষণ হয়নি।');
  }
}
