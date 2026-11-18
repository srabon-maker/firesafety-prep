
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
          throw Exception('Could not get a Google ID token. Please try again.');
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
            'Login was not completed. Please try again.',
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorBackground = isDark
        ? const Color(0xFF3A2028)
        : const Color(0xFFFFF0F0);
    final errorForeground = isDark
        ? const Color(0xFFFFCDD2)
        : const Color(0xFF9B1C25);
    final errorBorder = isDark
        ? const Color(0xFF87505A)
        : const Color(0xFFE6A3A9);

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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Keep the original logo artwork; round only its corners.
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: scheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.25 : 0.10,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: Image.asset(
                        'assets/fire_safety_job_prep_logo.png',
                        height: 136,
                        width: 136,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 136,
                            width: 136,
                            alignment: Alignment.center,
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              size: 76,
                              color: scheme.primary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    'Fire Safety BD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome to Fire Safety BD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Login to access all services',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _loading ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        disabledBackgroundColor:
                            scheme.surfaceContainerHighest,
                        disabledForegroundColor: scheme.onSurfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: _loading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 21,
                                  width: 21,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Flexible(
                                  child: Text('Please wait...'),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.g_mobiledata, size: 34),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Continue with Google',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: errorBackground,
                        border: Border.all(color: errorBorder),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: errorForeground),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Login Error',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: errorForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              color: errorForeground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: errorForeground,
                            ),
                            onPressed: () {
                              setState(() => _errorMessage = null);
                            },
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'New users will need to complete registration\n'
                    'after Google Login.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
