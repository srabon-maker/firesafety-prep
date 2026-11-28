import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/marketplace_category.dart';
import '../models/marketplace_item.dart';
import 'auth_service.dart';

class _TransientMarketplaceRead implements Exception {
  const _TransientMarketplaceRead(this.statusCode);
  final int statusCode;
  @override
  String toString() => 'Marketplace temporarily unavailable (HTTP $statusCode)';
}

class MarketplaceApiService {
  MarketplaceApiService._();

  static final MarketplaceApiService instance = MarketplaceApiService._();

  static const String apiBaseUrl =
      'https://fire.manobikishwarganj.com/api/marketplace/';
  static const String productsEndpoint = 'products.php';
  static const String servicesEndpoint = 'services.php';
  static const String categoriesEndpoint = 'categories.php';
  static const Duration requestTimeout = Duration(seconds: 20);

  Future<Map<String, String>> _headers({bool requireAuth = false}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (requireAuth) {
      final token = await AuthService.instance.getSessionToken();
      if (token == null || token.isEmpty) {
        throw Exception('অনুগ্রহ করে লগইন করুন।');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const FormatException('সার্ভারের উত্তর সঠিক JSON নয়।');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('সার্ভারের উত্তর সঠিক নয়।');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ?? 'অনুরোধ সম্পন্ন করা যায়নি।',
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requireAuth = false,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$endpoint')
        .replace(queryParameters: queryParameters);
    final response = await http
        .get(uri, headers: await _headers(requireAuth: requireAuth))
        .timeout(requestTimeout);
    return _decodeResponse(response);
  }

  // Retry only idempotent public catalog reads, never cart/order mutations.
  static Future<T> retryPublicRead<T>(Future<T> Function() read, {
    Duration delay = const Duration(milliseconds: 600),
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await read();
      } catch (error) {
        final transient = error is TimeoutException ||
            error is http.ClientException ||
            error is _TransientMarketplaceRead;
        if (!transient || attempt >= 1) rethrow;
        await Future<void>.delayed(delay);
      }
    }
  }

  Future<Map<String, dynamic>> getPublic(String endpoint) =>
      retryPublicRead(() async {
        final response = await http.get(
          Uri.parse('$apiBaseUrl$endpoint'),
          headers: await _headers(),
        ).timeout(requestTimeout);
        if (const [408, 500, 502, 503, 504].contains(response.statusCode)) {
          throw _TransientMarketplaceRead(response.statusCode);
        }
        return _decodeResponse(response);
      });

  Future<Map<String, dynamic>> post(
    String endpoint, {
    required Map<String, dynamic> body,
    bool requireAuth = true,
  }) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl$endpoint'),
          headers: await _headers(requireAuth: requireAuth),
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    return _decodeResponse(response);
  }

  static List<dynamic> _dataArray(Map<String, dynamic> response, String key) {
    dynamic items = response['data'] ??
        response[key] ??
        response['items'] ??
        response['results'];
    if (items is Map) {
      items = items[key] ?? items['items'] ?? items['results'];
    }
    if (items is! List) {
      throw const FormatException('API-এর তালিকার ধরন সঠিক নয়।');
    }
    return items;
  }

  static List<MarketplaceItem> parseCatalogResponse(
    Map<String, dynamic> response, {
    required bool isService,
  }) {
    final items = _dataArray(response, isService ? 'services' : 'products');
    return items.map((raw) {
      if (raw is! Map) {
        throw const FormatException('পণ্য বা সেবার তথ্য সঠিক নয়।');
      }
      final item = MarketplaceItem.fromJson(
        Map<String, dynamic>.from(raw),
        isService: isService,
      );
      if (item.id.isEmpty || item.name.isEmpty) {
        throw const FormatException('পণ্য বা সেবার ID অথবা নাম পাওয়া যায়নি।');
      }
      return item;
    }).toList(growable: false);
  }

  static List<MarketplaceCategory> parseCategoriesResponse(
    Map<String, dynamic> response, {
    required bool isService,
  }) {
    final items = _dataArray(response, 'categories');
    return items.map((raw) {
      if (raw is! Map) {
        throw const FormatException('ক্যাটাগরির তথ্য সঠিক নয়।');
      }
      return MarketplaceCategory.fromJson(
        Map<String, dynamic>.from(raw),
      );
    }).where((category) => category.supports(isService: isService))
        .toList(growable: false);
  }

  Future<List<MarketplaceItem>> fetchCatalog({
    required bool isService,
  }) async {
    final response = await getPublic(
      isService ? servicesEndpoint : productsEndpoint,
    );
    return parseCatalogResponse(response, isService: isService);
  }

  Future<List<MarketplaceCategory>> fetchCategories({
    required bool isService,
  }) async {
    final response = await getPublic(categoriesEndpoint);
    return parseCategoriesResponse(response, isService: isService);
  }
}
