
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String webClientId =
      '489619291156-dmva2n4skh4snd9qbl0ne2tionpm92b9.apps.googleusercontent.com';

  static const String apiBaseUrl =
      'https://fire.manobikishwarganj.com/api/auth/';

  static const String _sessionKey = 'fire_safety_session_token';

  final FlutterSecureStorage _storage =
      const FlutterSecureStorage();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await _googleSignIn.initialize(
      serverClientId: webClientId,
    );

    _initialized = true;
  }

  // --------------------------------------------------
  // GOOGLE SIGN IN
  // --------------------------------------------------

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    await initialize();

    try {
      final account = await _googleSignIn.authenticate();

      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google ID Token পাওয়া যায়নি।');
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
      ).timeout(const Duration(seconds: 30));

      final result = _decodeResponse(response);

      // First-time user: registration required
      if (result['needs_registration'] == true) {
        return {
          ...result,
          'google_user': result['google_user'] ??
              {
                'name': account.displayName ?? '',
                'email': account.email,
                'photo': account.photoUrl ?? '',
              },
        };
      }

      // Existing user: save session
      final token = result['session_token'];

      if (result['success'] == true &&
          token is String &&
          token.isNotEmpty) {
        await saveSession(token);
        return result;
      }

      throw Exception(
        result['message'] ?? 'Google Login সফল হয়নি।',
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }

      throw Exception('Google Login সমস্যা: ${e.description ?? e.code}');
    } on http.ClientException {
      throw Exception('সার্ভারের সঙ্গে সংযোগ করা যাচ্ছে না।');
    }
  }

  // --------------------------------------------------
  // REGISTRATION
  // --------------------------------------------------

  Future<Map<String, dynamic>> register({
    required String idToken,
    required String fullName,
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
        'mobile_number': mobileNumber,
        'current_status': currentStatus,
        'company_name': companyName ?? '',
        'designation': designation ?? '',
        'job_location': jobLocation ?? '',
        'current_address': currentAddress ?? '',
      }),
    ).timeout(const Duration(seconds: 30));

    final result = _decodeResponse(response);

    final token = result['session_token'];

    if (result['success'] == true &&
        token is String &&
        token.isNotEmpty) {
      await saveSession(token);
      return result;
    }

    throw Exception(
      result['message'] ?? 'Registration সফল হয়নি।',
    );
  }

  // --------------------------------------------------
  // SESSION STORAGE
  // --------------------------------------------------

  Future<void> saveSession(String token) async {
    await _storage.write(
      key: _sessionKey,
      value: token,
    );
  }

  Future<String?> getSession() async {
    return _storage.read(key: _sessionKey);
  }

  // --------------------------------------------------
  // VALIDATE CURRENT SESSION
  // --------------------------------------------------

  Future<Map<String, dynamic>?> validateSession() async {
    final token = await getSession();

    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('${apiBaseUrl}me.php'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      final result = _decodeResponse(response);

      if (result['success'] == true) {
        return result;
      }

      await _storage.delete(key: _sessionKey);
      return null;
    } catch (_) {
      // Network error: do not erase a potentially valid session.
      rethrow;
    }
  }

  Future<bool> isLoggedIn() async {
    final result = await validateSession();
    return result != null;
  }

  // --------------------------------------------------
  // LOGOUT
  // --------------------------------------------------

  Future<void> logout() async {
    final token = await getSession();

    try {
      if (token != null && token.isNotEmpty) {
        await http.post(
          Uri.parse('${apiBaseUrl}logout.php'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 15));
      }
    } finally {
      // Always clear local session.
      await _storage.delete(key: _sessionKey);

      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Local session is already cleared.
      }
    }
  }

  // --------------------------------------------------
  // API RESPONSE HANDLER
  // --------------------------------------------------

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    Map<String, dynamic> result;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid API response.');
      }

      result = decoded;
    } catch (_) {
      throw Exception(
        'সার্ভার থেকে সঠিক তথ্য পাওয়া যায়নি। HTTP ${response.statusCode}',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        result['message'] ?? 'Server error: ${response.statusCode}',
      );
    }

    return result;
  }
}
