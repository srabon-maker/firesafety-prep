import 'dart:convert';
import 'dart:typed_data';
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
  static Future<Uint8List?> photoBytes(String key) async {
    if (!RegExp(r'^[a-f0-9]{32}
  static Uri? safeLink(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty ? uri : null;
  }
}
).hasMatch(key)) return null;
    try {
      final token = await AuthService.instance.getSessionToken();
      if (token == null || token.isEmpty) return null;
      final uri = Uri.parse(endpoint).replace(queryParameters: {'action':'photo','key':key});
      final response = await http.get(uri, headers: {
        'Accept': 'image/jpeg', 'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));
      if (await AuthService.instance.getSessionToken() != token ||
          response.statusCode != 200 ||
          response.headers['content-type']?.split(';').first != 'image/jpeg' ||
          response.bodyBytes.length > 2097152) return null;
      return response.bodyBytes;
    } catch (_) { return null; }
  }
  static Uri? safeLink(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty ? uri : null;
  }
}
