import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/community_post.dart';
import 'auth_service.dart';

class CommunityService {
  CommunityService._();
  static final instance = CommunityService._();
  static const _url = 'https://fire.manobikishwarganj.com/api/community/index.php';
  static const _timeout = Duration(seconds: 30);

  Future<Map<String, String>> _headers({bool requireLogin = false}) async {
    final token = await AuthService.instance.getSessionToken();
    if (requireLogin && (token == null || token.isEmpty)) {
      throw Exception('পোস্ট করতে লগইন করুন।');
    }
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('সার্ভার থেকে সঠিক উত্তর পাওয়া যায়নি।');
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('সার্ভারের উত্তর সঠিক নয়।');
    }
    if (response.statusCode < 200 || response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(decoded['message']?.toString() ?? 'অনুরোধটি সম্পন্ন হয়নি।');
    }
    return decoded;
  }

  Future<List<CommunityPost>> feed({String sort = 'latest'}) async {
    final uri = Uri.parse(_url).replace(queryParameters: {
      'action': 'feed', 'sort': sort,
    });
    final response = await http.get(uri, headers: await _headers()).timeout(_timeout);
    final data = _decode(response)['data'];
    if (data is! List) throw Exception('পোস্টের তালিকা সঠিক নয়।');
    return data.map((item) =>
        CommunityPost.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<void> createPost({
    required String body,
    Uint8List? image,
    String? imageName,
  }) async {
    final request = http.MultipartRequest(
      'POST', Uri.parse('$_url?action=create'),
    );
    request.headers.addAll(await _headers(requireLogin: true));
    request.fields['body'] = body;
    if (image != null) {
      if (image.lengthInBytes > 5 * 1024 * 1024) {
        throw Exception('ছবির সাইজ সর্বোচ্চ ৫ MB হতে পারবে।');
      }
      request.files.add(http.MultipartFile.fromBytes(
        'image', image, filename: imageName ?? 'photo.jpg',
      ));
    }
    final streamed = await request.send().timeout(_timeout);
    _decode(await http.Response.fromStream(streamed));
  }

  Future<void> toggleLike(int postId) async {
    await _post('like', {'post_id': postId});
  }

  Future<void> comment(int postId, String text) async {
    await _post('comment', {'post_id': postId, 'text': text});
  }

  Future<List<Comment>> comments(int postId) async {
    final uri = Uri.parse(_url).replace(queryParameters: {
      'action': 'comments', 'post_id': '$postId',
    });
    final response = await http.get(uri, headers: await _headers()).timeout(_timeout);
    final data = _decode(response)['data'];
    if (data is! List) throw Exception('মন্তব্যের তালিকা সঠিক নয়।');
    return data.map((item) =>
        Comment.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<void> _post(String action, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_url?action=$action'),
      headers: {
        ...await _headers(requireLogin: true),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    ).timeout(_timeout);
    _decode(response);
  }
}
