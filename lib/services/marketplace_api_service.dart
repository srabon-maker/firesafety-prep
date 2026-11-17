
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class MarketplaceApiService {
  MarketplaceApiService._();

  static final MarketplaceApiService instance =
      MarketplaceApiService._();

  static const String apiBaseUrl =
      'https://fire.manobikishwarganj.com/api/marketplace/';

  Future<Map<String, String>> _headers({
    bool requireAuth = false,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (requireAuth) {
      final token =
          await AuthService.instance.getSessionToken();

      if (token == null || token.isEmpty) {
        throw Exception('অর্ডার করতে Login করুন।');
      }

      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('সার্ভারের Response সঠিক নয়।');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('সার্ভারের Response সঠিক নয়।');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] == false) {
      throw Exception(
        decoded['message']?.toString() ??
            'অনুরোধ সম্পন্ন করা যায়নি।',
      );
    }

    return decoded;
  }

  // GET API
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requireAuth = false,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$endpoint')
        .replace(queryParameters: queryParameters);

    final response = await http.get(
      uri,
      headers: await _headers(
        requireAuth: requireAuth,
      ),
    );

    return _decodeResponse(response);
  }

  // POST API
  Future<Map<String, dynamic>> post(
    String endpoint, {
    required Map<String, dynamic> body,
    bool requireAuth = true,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl$endpoint'),
      headers: await _headers(
        requireAuth: requireAuth,
      ),
      body: jsonEncode(body),
    );

    return _decodeResponse(response);
  }
}
