import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Requests are bound to the login token present when this service is created.
class PremiumService {
  PremiumService({Future<String?> Function()? currentToken,http.Client? client})
      : _currentToken=currentToken??AuthService.instance.getSessionToken,_client=client {
    _session=_currentToken();
  }
  final Future<String?> Function() _currentToken;
  final http.Client? _client;
  late final Future<String?> _session;
  static const root='https://fire.manobikishwarganj.com/api';
  Future<Map<String,dynamic>> _get(String path,Map<String,String> query) async {
    final token=await _session;
    if(token==null||token.isEmpty||await _currentToken()!=token) {
      throw const FormatException('আবার লগইন করুন।');
    }
    final uri=Uri.parse('$root/$path').replace(queryParameters:query);
    final headers={'Accept':'application/json','Authorization':'Bearer $token'};
    final response=await (_client?.get(uri,headers:headers)??http.get(uri,headers:headers)).timeout(const Duration(seconds:15));
    if(await _currentToken()!=token||response.statusCode==401)throw const FormatException('সেশন শেষ হয়েছে।');
    final data=jsonDecode(utf8.decode(response.bodyBytes));
    if(response.statusCode!=200||data is! Map<String,dynamic>||data['success']!=true)throw const FormatException('তথ্য পাওয়া যায়নি।');
    return data;
  }
  Future<Map<String,dynamic>> status()=>_get('premium/index.php',{});
  Future<Map<String,dynamic>> interviews(Map<String,String> filters)=>_get('homepage/index.php',{...filters,'action':'interviews','premium_preview':'1'});
}
