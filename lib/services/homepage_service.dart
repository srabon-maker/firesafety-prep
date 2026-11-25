import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class HomepageService {
  static const defaultSections = <String>[
    'banners', 'marketplace', 'progress', 'jobs', 'topics', 'notes', 'community', 'tips'
  ];
  static const endpoint = 'https://fire.manobikishwarganj.com/api/homepage/index.php';

  static List<Map<String, dynamic>> rows(dynamic raw) {
    if (raw is! List) throw const FormatException('Invalid content list');
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static List<String> strings(dynamic raw) {
    if (raw is! List) throw const FormatException('Invalid content filter');
    return raw.whereType<String>().toList();
  }

  static List<String> sections(dynamic raw) =>
      strings(raw).where(defaultSections.contains).toSet().toList();

  static Future<Map<String, dynamic>> fetch(String action,
      {Map<String, String> filters = const {}, http.Client? client}) async {
    final uri = Uri.parse(endpoint).replace(queryParameters: {'action': action, ...filters});
    final token=action=='question_categories'&&client==null?await AuthService.instance.getSessionToken():null;
    final headers={'Accept':'application/json',if(token!=null&&token.isNotEmpty)'Authorization':'Bearer $token'};
    final response = await (client == null ? http.get(uri,headers:headers) : client.get(uri,headers:headers))
        .timeout(const Duration(seconds: 15));
    if(action=='question_categories'&&client==null&&await AuthService.instance.getSessionToken()!=token)throw const FormatException('Session changed');
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200 || data is! Map<String, dynamic> || data['success'] != true) {
      throw const FormatException('Content unavailable');
    }
    return data;
  }

  static String text(Map<String, dynamic> row, String key) =>
      row[key]?.toString() ?? '';

  static bool safeImage(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' &&
        uri.host == 'fire.manobikishwarganj.com' &&
        !uri.hasPort && uri.userInfo.isEmpty && !uri.hasQuery &&
        !uri.hasFragment &&
        RegExp(r'^/uploads/[A-Za-z0-9/_-]+\.(png|jpe?g|webp)$').hasMatch(uri.path);
  }
}
