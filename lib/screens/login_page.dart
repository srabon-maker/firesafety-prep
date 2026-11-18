
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'registration_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color maroon = Color(0xFF650D18);

  bool _loading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result =
          await AuthService.instance.signInWithGoogle();

      if (!mounted) return;

      if (result == null) {
        return;
      }

      // First-time user: Registration required
      if (result['needs_registration'] == true) {
        final googleUser =
            result['google_user'] as Map<String, dynamic>? ?? {};

        final idToken = result['id_token']?.toString() ?? '';

        if (idToken.isEmpty) {
          throw Exception('Google ID Token পাওয়া যায়নি।');
        }

        final registered = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => RegistrationPage(
              idToken: idToken,
              googleUser: googleUser,
            ),
          ),
        );

        if (!mounted) return;

        if (registered == true) {
          Navigator.pop(context, true);
        }

        return;
      }

      // Existing user: AuthService already saved the session
      if (result['needs_registration'] == false) {
        Navigator.pop(context, true);
        return;
      }

      throw Exception(
        result['message']?.toString() ??
            'Login সফল হয়নি। আবার চেষ্টা করুন।',
      );
    } catch (e, stackTrace) {
      debugPrint('LOGIN PAGE ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString()
            .replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Image.asset(
                  'assets/fire_safety_job_prep_logo.png',
                  height: 125,
                  width: 125,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.local_fire_department,
                      size: 110,
                      color: maroon,
                    );
                  },
                ),

                const SizedBox(height: 24),

                Text(
                  'Fire Safety BD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Welcome to Fire Safety BD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Login to access all services',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 35),

                // Google Login Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _login,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: maroon,
                      side: const BorderSide(
                        color: maroon,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 21,
                                width: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: maroon,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Please wait...'),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.g_mobiledata,
                                size: 34,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                // Detailed error display
                if (_errorMessage != null) ...[
                  const SizedBox(height: 22),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(
                        color: Colors.red.shade300,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Login Error',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.red.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 25),

                Text(
                  'New users will need to complete registration '
                  'after Google Login.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
