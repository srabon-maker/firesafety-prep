import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class CareerService {
  static const endpoint = 'https://fire.manobikishwarganj.com/api/career/index.php';
  static Future<Map<String, dynamic>> request(String action,
      {Map<String, dynamic>? body, Map<String, String> filters = const {}}) async {
    final token = await AuthService.instance.getSessionToken();
    if (token == null || token.isEmpty) throw const FormatException('Login required');
    final uri = Uri.parse(endpoint).replace(queryParameters: {'action': action, ...filters});
    final headers = {'Accept': 'application/json', 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json'};
    final response = await (body == null
        ? http.get(uri, headers: headers)
        : http.post(uri, headers: headers, body: jsonEncode({...body, 'action': action})))
        .timeout(const Duration(seconds: 20));
    if (await AuthService.instance.getSessionToken() != token) {
      throw const FormatException('Session changed');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic> || response.statusCode != 200 || data['success'] != true) {
      throw FormatException(data is Map ? (data['message']?.toString() ?? 'Career service unavailable') : 'Career service unavailable');
    }
    return data;
  }
  static List<Map<String, dynamic>> rows(Map<String, dynamic> data) =>
      (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  static String text(Map<String, dynamic> row, String key) => row[key]?.toString() ?? '';
  static String photoUrl(String path) => 'https://fire.manobikishwarganj.com/$path';
  static Uri? safeLink(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty ? uri : null;
  }
}
