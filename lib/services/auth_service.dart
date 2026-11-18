
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  // Google OAuth Web Client ID
  // Certificate registered in the Google Cloud Android OAuth client for
  // Codemagic's permanent signing identity (not a secret).
  static const String registeredReleaseSha1 =
      '5E:FA:D5:39:A3:B4:1A:AB:50:8C:AF:D8:1D:8C:51:81:25:B0:EA:FC';
  static const MethodChannel _appIdentityChannel =
      MethodChannel('com.firesafetybd/app_identity');

  static const String webClientId =
      '489619291156-dmva2n4skh4snd9qbl0ne2tionpm92b9.apps.googleusercontent.com';

  // Fire Safety BD API
  static const String apiBaseUrl =
      'https://fire.manobikishwarganj.com/api/auth/';

  static const String _sessionKey = 'fire_safety_session_token';
  static const Duration _requestTimeout = Duration(seconds: 20);

  final FlutterSecureStorage _storage =
      const FlutterSecureStorage();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInitialized = false;

  void _log(String message) {
    debugPrint('[FIRE SAFETY AUTH] $message');
  }

  // --------------------------------------------------
  // GOOGLE SIGN-IN INITIALIZATION
  // --------------------------------------------------

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) return;

    _log('Initializing Google Sign-In...');

    try {
      await _googleSignIn.initialize(
        serverClientId: webClientId,
      );

      _googleInitialized = true;

      _log('Google Sign-In initialized successfully.');
    } catch (e, stackTrace) {
      _log('INITIALIZATION ERROR: $e');
      _log('$stackTrace');
      rethrow;
    }
  }

  // --------------------------------------------------
  // GOOGLE SIGN-IN
  // --------------------------------------------------

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    var signInStage = 'initialization';
    String? installedSha1;
    String? installedPackage;
    _log('STEP 1: Google login started.');

    try {
      await _initializeGoogleSignIn();

      // Do not sign out immediately before opening the account picker.
      // Explicit sign-out is handled by logout().

      // Read the certificate from the APK actually installed on the device,
      // not from the Codemagic build log or the uploaded keystore.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final identity = await _appIdentityChannel
              .invokeMapMethod<String, dynamic>('getSigningIdentity');
          installedSha1 = identity?['sha1'] as String?;
          installedPackage = identity?['packageName'] as String?;
          _log('Installed APK package: $installedPackage');
          _log('Installed APK signing SHA-1: $installedSha1');
        } catch (_) {
          _log('Installed APK signing information unavailable.');
        }
      }

      signInStage = 'google_account_authentication';
      _log('STEP 2: Waiting for Google account selection.');

      final GoogleSignInAccount account =
          await _googleSignIn.authenticate();

      signInStage = 'google_id_token';
      _log('STEP 3: Google account selected.');
      _log('Google email: ${account.email}');
      _log('Google ID received: ${account.id.isNotEmpty}');

      _log('STEP 4: Requesting Google ID Token.');

      final String? idToken =
          account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        _log('ERROR: Google ID Token is NULL or EMPTY.');

        throw Exception(
          'Google থেকে ID Token পাওয়া যায়নি। আবার চেষ্টা করুন।',
        );
      }

      _log('STEP 5: Google ID Token received successfully.');

      signInStage = 'server_login';
      _log('STEP 6: Sending login request to PHP API.');

      final response = await http.post(
        Uri.parse('${apiBaseUrl}google_login.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'id_token': idToken}),
      ).timeout(_requestTimeout);

      _log('STEP 7: PHP API response received.');
      _log('HTTP Status: ${response.statusCode}');

      final data = _decodeResponse(response);

      _log('STEP 8: PHP API response decoded successfully.');

      // New user: Registration required
      if (data['needs_registration'] == true) {
        _log('New user detected. Registration required.');

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

      // Existing user: Save session
      final token = data['session_token'];

      if (token == null || token.toString().isEmpty) {
        throw Exception(
          'সার্ভার থেকে Session Token পাওয়া যায়নি।',
        );
      }

      await _storage.write(
        key: _sessionKey,
        value: token.toString(),
      );

      _log('STEP 9: Session saved successfully.');
      _log('GOOGLE LOGIN COMPLETED.');

      return {
        'needs_registration': false,
        'session_token': token.toString(),
        'user': data['user'],
      };
    } on GoogleSignInException catch (e, stackTrace) {
      _log('GOOGLE SIGN-IN EXCEPTION: ${e.code}');
      _log('Google error details: $e');
      _log('$stackTrace');
      // The platform can report "canceled" even after a user taps an
      // account. Include the non-secret SDK code and failing stage so that
      // support can distinguish this from a server or token failure.
      final diagnostic = 'Code: ${e.code.name}; Stage: $signInStage';
      final nativeDescription = e.description ?? '';
      final nativeHint = nativeDescription.contains('Account reauth failed')
          ? 'Android detail: Account reauth failed.'
          : nativeDescription.contains('Developer console is not set up')
              ? 'Android detail: Developer console configuration error.'
              : nativeDescription.contains('Network error')
                  ? 'Android detail: Network error.'
                  : '';
      final apkIdentity = installedSha1 == null
          ? ''
          : '\nInstalled APK SHA-1: $installedSha1';
      final signingMismatch = installedSha1 != null &&
          (installedSha1.toUpperCase() != registeredReleaseSha1 ||
              installedPackage != 'com.firesafetybd');
      if (signingMismatch) {
        throw Exception(
          'The installed APK signing identity differs from the Android OAuth '
          'client. Register this APK package and SHA-1 in Google Cloud, or '
          'install the intended permanent-release APK.\n'
          '$diagnostic$apkIdentity',
        );
      }
      final extra = nativeHint.isEmpty ? '' : '\n$nativeHint';
      _log('GOOGLE AUTH DIAGNOSTIC: $diagnostic');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception(
          'Google Sign-In was interrupted. Please try again.\n'
          '$diagnostic$extra$apkIdentity',
        );
      }
      throw Exception(
        'Google Sign-In failed. Please try again.\n'
        '$diagnostic$extra$apkIdentity',
      );
    } on TimeoutException {
      throw Exception('Login server-এর Response আসতে দেরি হচ্ছে। আবার চেষ্টা করুন।');
    } catch (e, stackTrace) {
      _log('GOOGLE LOGIN ERROR: $e');
      _log('$stackTrace');
      rethrow;
    }
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
    _log('Registration started.');

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
    ).timeout(_requestTimeout);

    _log('Registration HTTP Status: ${response.statusCode}');

    final data = _decodeResponse(response);

    final token = data['session_token'];

    if (token == null || token.toString().isEmpty) {
      throw Exception(
        'Registration-এর পর Session Token পাওয়া যায়নি।',
      );
    }

    await _storage.write(
      key: _sessionKey,
      value: token.toString(),
    );

    _log('Registration completed successfully.');

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
    ).timeout(_requestTimeout);

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
  // PROFILE MANAGEMENT (authenticated server endpoints)
  // --------------------------------------------------

  Future<void> updateProfile({
    required String fullName,
    required String mobileNumber,
    required String currentStatus,
    required String companyName,
    required String designation,
    required String jobLocation,
    required String currentAddress,
  }) async {
    final token = await getSessionToken();
    if (token == null || token.isEmpty) {
      throw Exception('সেশন শেষ হয়েছে। আবার লগইন করুন।');
    }

    final response = await http.post(
      Uri.parse('${apiBaseUrl}update_profile.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'full_name': fullName,
        'mobile_number': mobileNumber,
        'current_status': currentStatus,
        'company_name': companyName,
        'designation': designation,
        'job_location': jobLocation,
        'current_address': currentAddress,
      }),
    ).timeout(_requestTimeout);

    final data = _decodeResponse(response);
    if (data['success'] != true) {
      throw Exception('প্রোফাইল আপডেট নিশ্চিত করা যায়নি।');
    }
  }

  /// Delete the authenticated account on the server before removing the
  /// local session. A failed request never signs the user out or pretends
  /// that their data was deleted.
  Future<void> deleteAccount({required String email}) async {
    final token = await getSessionToken();
    if (token == null || token.isEmpty) {
      throw Exception('সেশন শেষ হয়েছে। আবার লগইন করুন।');
    }

    final response = await http.post(
      Uri.parse('${apiBaseUrl}delete_account.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'confirmation': 'DELETE_MY_ACCOUNT'}),
    ).timeout(_requestTimeout);

    final data = _decodeResponse(response);
    if (data['success'] != true || data['deleted'] != true) {
      throw Exception('সার্ভার অ্যাকাউন্ট মুছে ফেলা নিশ্চিত করেনি।');
    }

    // Clear locally cached registration suggestions for this Google email.
    try {
      final emailKey = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      await _storage.delete(key: 'registration_suggestions_$emailKey');
    } catch (e) {
      _log('Could not clear cached registration suggestions: $e');
    }
    await _clearLocalSession();
  }

  Future<void> _clearLocalSession() async {
    await _storage.delete(key: _sessionKey);
    try {
      await _initializeGoogleSignIn();
      await _googleSignIn.signOut();
    } catch (e) {
      _log('Google sign-out error: $e');
    }
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
        ).timeout(_requestTimeout);
      }
    } finally {
      await _clearLocalSession();
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
