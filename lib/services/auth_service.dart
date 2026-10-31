
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String webClientId =
      '489619291156-dmva2n4skh4snd9qbl0ne2tionpm92b9.apps.googleusercontent.com';

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

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    await initialize();

    try {
      final account = await _googleSignIn.authenticate();

      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google ID Token পাওয়া যায়নি।');
      }

      return {
        'idToken': idToken,
        'name': account.displayName ?? '',
        'email': account.email,
        'photo': account.photoUrl ?? '',
      };
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> saveSession(String token) async {
    await _storage.write(
      key: _sessionKey,
      value: token,
    );
  }

  Future<String?> getSession() async {
    return _storage.read(key: _sessionKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getSession();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await _storage.delete(key: _sessionKey);

    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Local session has already been cleared.
    }
  }
}
