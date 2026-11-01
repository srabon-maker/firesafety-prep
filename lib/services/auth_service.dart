
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  // Google OAuth Web Client ID
  static const String webClientId =
      '489619291156-dmva2n4skh4snd9qbl0ne2tionpm92b9.apps.googleusercontent.com';

  // Fire Safety BD API
  static const String apiBaseUrl =
      'https://fire.manobikishwarganj.com/api/auth/';

  static const String _sessionKey = 'fire_safety_session_token';

  final FlutterSecureStorage _storage =
      const FlutterSecureStorage();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInitialized = false;

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) return;

    await _googleSignIn.initialize(
      serverClientId: webClientId,
    );

    _googleInitialized = true;
  }

  // --------------------------------------------------
  // GOOGLE SIGN-IN
  // --------------------------------------------------

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    await _initializeGoogleSignIn();

    final GoogleSignInAccount account =
        await _googleSignIn.authenticate();

    final String? idToken =
        account.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Google থেকে ID Token পাওয়া যায়নি। আবার চেষ্টা করুন।',
      );
    }

    final response = await http.post(
      Uri.parse('${apiBaseUrl}google_login.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'id_token': idToken,
      }),
    );

    final data = _decodeResponse(response);

    // নতুন ব্যবহারকারী: Registration Page-এ পাঠানোর তথ্য
    if (data['needs_registration'] == true) {
      return {
        'needs_registration': true,
        'id_token': idToken,
        'google_user': data['google_user'] ??
            {
              'name': account.displayName ?? '',
              'email': account.email,
              'photo': account.photoUrl,
              'google_id': account.id,
            },
      };
    }

    // পুরোনো ব্যবহারকারী: Session সংরক্ষণ
    final token = data['session_token'];

    if (token == null || token.toString().isEmpty) {
      throw Exception('সার্ভার থেকে Session Token পাওয়া যায়নি।');
    }

    await _storage.write(
      key: _sessionKey,
      value: token.toString(),
    );

    return {
      'needs_registration': false,
      'session_token': token.toString(),
      'user': data['user'],
    };
  }

  // --------------------------------------------------
  // USER REGISTRATION
  // --------------------------------------------------

  Future<Map<String, dynamic>> register({
    required String idToken,
    required String fullName,
    required String email,
    required String mobileNumber,
    required String currentStatus,
    String? companyName,
    String? designation,
    String? jobLocation,
    String? currentAddress,
  }) async {
    final response = await http.post(
      Uri.parse('${apiBaseUrl}register.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'id_token': idToken,
        'full_name': fullName,
        'email': email,
        'mobile_number': mobileNumber,
        'current_status': currentStatus,
        'company_name': companyName,
        'designation': designation,
        'job_location': jobLocation,
        'current_address': currentAddress,
      }),
    );

    final data = _decodeResponse(response);

    final token = data['session_token'];

    if (token == null || token.toString().isEmpty) {
      throw Exception('Registration-এর পর Session Token পাওয়া যায়নি।');
    }

    await _storage.write(
      key: _sessionKey,
      value: token.toString(),
    );

    return data;
  }

  // --------------------------------------------------
  // GET SAVED SESSION TOKEN
  // --------------------------------------------------

  Future<String?> getSessionToken() async {
    return await _storage.read(key: _sessionKey);
  }

  // --------------------------------------------------
  // VALIDATE SESSION WITH SERVER
  // --------------------------------------------------

  Future<Map<String, dynamic>?> validateSession() async {
    final token = await getSessionToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    final response = await http.get(
      Uri.parse('${apiBaseUrl}me.php'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401 ||
        response.statusCode == 403) {
      await _storage.delete(key: _sessionKey);
      return null;
    }

    final data = _decodeResponse(response);

    if (data['success'] == false ||
        data['authenticated'] == false) {
      await _storage.delete(key: _sessionKey);
      return null;
    }

    return data;
  }

  // --------------------------------------------------
  // LOGOUT
  // --------------------------------------------------

  Future<void> logout() async {
    final token = await getSessionToken();

    try {
      if (token != null && token.isNotEmpty) {
        await http.post(
          Uri.parse('${apiBaseUrl}logout.php'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } finally {
      // Local session অবশ্যই মুছে ফেলবে
      await _storage.delete(key: _sessionKey);

      try {
        await _initializeGoogleSignIn();
        await _googleSignIn.signOut();
      } catch (_) {
        // Google sign-out ব্যর্থ হলেও local session মুছে যাবে
      }
    }
  }

  // --------------------------------------------------
  // API RESPONSE HANDLER
  // --------------------------------------------------

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    Map<String, dynamic> data;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('সার্ভারের Response সঠিক নয়।');
      }

      data = decoded;
    } catch (_) {
      throw Exception(
        'সার্ভার থেকে সঠিক JSON Response পাওয়া যায়নি।',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data['message']?.toString() ??
            'সার্ভার Error: ${response.statusCode}',
      );
    }

    if (data['success'] == false) {
      throw Exception(
        data['message']?.toString() ??
            'অনুরোধটি সম্পন্ন করা যায়নি।',
      );
    }

    return data;
  }
}
