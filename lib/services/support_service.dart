import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class SupportService {
  SupportService({Future<String?> Function()? currentToken,http.Client? client})
      : _currentToken=currentToken??AuthService.instance.getSessionToken,_client=client {
    _session=_currentToken();
  }
  final Future<String?> Function() _currentToken;
  final http.Client? _client;
  late final Future<String?> _session;
  static const endpoint='https://fire.manobikishwarganj.com/api/support/index.php';
  Future<Map<String,dynamic>> _request({Map<String,String>? query,Map<String,dynamic>? body}) async{
    final token=await _session;
    if(token==null||token.isEmpty||await _currentToken()!=token)throw const FormatException('আবার লগইন করুন।');
    final uri=Uri.parse(endpoint).replace(queryParameters:query);
    final headers={'Accept':'application/json','Authorization':'Bearer $token'};
    final response=await (body==null?(_client?.get(uri,headers:headers)??http.get(uri,headers:headers)):
      (_client?.post(uri,headers:{...headers,'Content-Type':'application/json'},body:jsonEncode(body))??http.post(uri,headers:{...headers,'Content-Type':'application/json'},body:jsonEncode(body)))).timeout(const Duration(seconds:20));
    if(await _currentToken()!=token||response.statusCode==401)throw const FormatException('সেশন শেষ হয়েছে।');
    final data=jsonDecode(utf8.decode(response.bodyBytes));
    if(response.statusCode!=200||data is! Map<String,dynamic>||data['success']!=true)throw const FormatException('সহায়তার অনুরোধ সম্পন্ন হয়নি।');
    return data;
  }
  Future<Map<String,dynamic>> tickets(int page)=>_request(query:{'page':'$page'});
  Future<Map<String,dynamic>> thread(String id,{String? before})=>_request(query:{'ticket_id':id,if(before!=null)'before_id':before});
  Future<String> create(String subject,String plan,String message) async =>
    (await _request(body:{'action':'create','subject':subject,'plan_code':plan,'message':message}))['ticket_id'].toString();
  Future<void> hideMessage(String id,String messageId) async {
    await _request(body:{'action':'hide_message','ticket_id':id,'message_id':messageId});
  }
  Future<void> hideThread(String id) async {
    await _request(body:{'action':'hide_thread','ticket_id':id});
  }
  Future<void> reply(String id,String message) async{
    await _request(body:{'action':'reply','ticket_id':id,'message':message});
  }
}
