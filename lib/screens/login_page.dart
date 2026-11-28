
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../settings/app_settings.dart';
import 'registration_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.signIn});

  final Future<Map<String, dynamic>?> Function()? signIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
          await (widget.signIn ?? AuthService.instance.signInWithGoogle)();

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    String t(String bn, String en) => AppText.of(context, bn, en);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('লগইন', 'Sign in')),
        centerTitle: true,
        toolbarHeight: 52,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/fire_safety_job_prep_logo.png',
                      key: const ValueKey('login-brand-logo'),
                      height: 100,
                      width: 100,
                      fit: BoxFit.contain,
                      semanticLabel: 'Fire Safety BD',
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 100,
                        width: 100,
                        alignment: Alignment.center,
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          size: 54,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t('স্বাগতম', 'Welcome'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    t('এগিয়ে যেতে লগইন করুন', 'Sign in to continue'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey('login-google-button'),
                      onPressed: _loading ? null : _login,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 50),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF202124),
                        disabledBackgroundColor: scheme.surfaceContainerHighest,
                        disabledForegroundColor: scheme.onSurfaceVariant,
                        side: BorderSide(
                          color: _loading
                              ? scheme.outlineVariant
                              : const Color(0xFFDADCE0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_loading)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          else
                            const CustomPaint(
                              size: Size.square(20),
                              painter: _GoogleMarkPainter(),
                            ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _loading
                                  ? t('অপেক্ষা করুন…', 'Please wait…')
                                  : t('Google দিয়ে লগইন করুন',
                                      'Continue with Google'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('নতুনদের লগইনের পর নিবন্ধন করতে হবে।',
                        'New users register after signing in.'),
                    key: const ValueKey('login-registration-hint'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _LoginErrorCard(message: _errorMessage!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _LoginIssue { blocked, network, server, google, other }

_LoginIssue _issueFor(String message) {
  final m = message.toLowerCase();
  if (m.contains('imunify360') || m.contains('bot-protection') ||
      m.contains('bot protection')) {
    return _LoginIssue.blocked;
  }
  if (m.contains('network error') || m.contains('socketexception') ||
      m.contains('failed host lookup') || m.contains('network is unreachable') ||
      m.contains('connection refused') || m.contains('connection reset') ||
      m.contains('no internet') || m.contains('no address associated')) {
    return _LoginIssue.network;
  }
  if (m.contains('timeout') || m.contains('timed out') ||
      m.contains('response আসতে দেরি') || m.contains('json response') ||
      RegExp(r'(?:server|সার্ভার)\s*(?:error)?[: ]+5\d\d\b').hasMatch(m) ||
      m.contains('service unavailable')) {
    return _LoginIssue.server;
  }
  if (m.contains('google sign-in') || m.contains('google id token') ||
      m.contains('google থেকে id token') || m.contains('signing identity')) {
    return _LoginIssue.google;
  }
  return _LoginIssue.other;
}

class _LoginErrorCard extends StatelessWidget {
  const _LoginErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    String t(String bn, String en) => AppText.of(context, bn, en);
    final issue = _issueFor(message);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFFFB3BE) : const Color(0xFF98202F);
    final bodyColor = dark ? const Color(0xFFE8CCD0) : const Color(0xFF69434A);
    final background = dark ? const Color(0xFF322126) : const Color(0xFFFBECEE);
    final blocked = issue == _LoginIssue.blocked;
    final summary = switch (issue) {
      _LoginIssue.blocked => t(
        'Imunify360 নিরাপত্তাব্যবস্থা আপনার নেটওয়ার্কের অনুরোধ ব্লক করেছে।',
        'Imunify360 security has blocked a request from your network.'),
      _LoginIssue.network => t('ইন্টারনেট সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।',
        'Check your internet connection and try again.'),
      _LoginIssue.server => t('সার্ভার থেকে উত্তর পাওয়া যাচ্ছে না। কিছুক্ষণ পর চেষ্টা করুন।',
        'The server is not responding as expected. Try again later.'),
      _LoginIssue.google => t('Google লগইন সম্পন্ন হয়নি। আবার চেষ্টা করুন।',
        'Google sign-in did not complete. Try again.'),
      _LoginIssue.other => t('আবার লগইন করার চেষ্টা করুন।',
        'Please try signing in again.'),
    };
    // Keep diagnostic access compact. Do not echo arbitrary server bodies,
    // credentials or tokens. Preserve only known, non-secret SDK diagnostics.
    final diagnostics = <String>[
      if (blocked) 'Access denied by Imunify360 bot-protection.',
      if (message.toLowerCase().contains('signing identity differs'))
        'Installed APK signing identity differs from the registered release.',
      ...RegExp(r'Code: [A-Za-z_]+; Stage: [A-Za-z_]+')
        .allMatches(message).map((m) => m.group(0)!),
      ...RegExp(r'Installed APK SHA-1: (?:[0-9A-Fa-f]{2}:){19}[0-9A-Fa-f]{2}')
        .allMatches(message).map((m) => m.group(0)!),
      ...RegExp(r'Android detail: (?:Account reauth failed|Developer console configuration error|Network error)\.')
        .allMatches(message).map((m) => m.group(0)!),
    ];
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('login-error-card'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        decoration: BoxDecoration(color: background,
          borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(blocked ? Icons.gpp_maybe_outlined : Icons.error_outline_rounded,
              color: foreground, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(
              blocked ? t('লগইন বাধাগ্রস্ত হয়েছে', 'Sign-in blocked')
                : t('লগইন করা যায়নি', 'Sign-in failed'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                color: foreground),
            )),
            if (diagnostics.isNotEmpty)
              IconButton(
                tooltip: t('কারিগরি বিবরণ', 'Technical details'),
                color: foreground,
                iconSize: 18,
                onPressed: () => showDialog<void>(context: context,
                  builder: (dialog) => AlertDialog(
                    title: Text(t('কারিগরি বিবরণ', 'Technical details')),
                    content: SingleChildScrollView(child: SelectableText(
                      diagnostics.join('\n'), style: const TextStyle(fontSize: 13))),
                    actions: [TextButton(onPressed: () => Navigator.pop(dialog),
                      child: Text(t('বন্ধ করুন', 'Close')))],
                  )),
                icon: const Icon(Icons.info_outline_rounded),
              ),
          ]),
          Text(summary, style: TextStyle(fontSize: 13, height: 1.4, color: bodyColor)),
          if (blocked) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: foreground.withValues(alpha: .20)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.wifi_rounded, color: foreground, size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text(t(
                'মোবাইল ডাটা অথবা অন্য Wi-Fi নেটওয়ার্ক দিয়ে আবার লগইন করার চেষ্টা করুন।',
                'Try signing in using mobile data or another Wi-Fi network.'),
                style: TextStyle(fontSize: 12, height: 1.4, color: bodyColor))),
            ]),
          ],
        ]),
      ),
    );
  }
}

// Draw the four-color Google G without another package or network asset.
class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    void draw(Color color, Path path) {
      canvas.drawPath(path, Paint()..color = color);
    }

    draw(const Color(0xFF4285F4), Path()
      ..moveTo(43.6, 24.5)
      ..cubicTo(43.6, 23.1, 43.5, 21.7, 43.2, 20.4)
      ..lineTo(24, 20.4)..lineTo(24, 28.2)..lineTo(35, 28.2)
      ..cubicTo(34.5, 30.7, 33.1, 32.9, 30.9, 34.3)
      ..lineTo(30.9, 39.3)..lineTo(37.5, 39.3)
      ..cubicTo(41.4, 35.7, 43.6, 30.5, 43.6, 24.5)..close());
    draw(const Color(0xFF34A853), Path()
      ..moveTo(24, 44)
      ..cubicTo(29.5, 44, 34.2, 42.2, 37.5, 39.3)
      ..lineTo(30.9, 34.3)
      ..cubicTo(29.1, 35.5, 26.7, 36.2, 24, 36.2)
      ..cubicTo(18.7, 36.2, 14.2, 32.6, 12.6, 27.8)
      ..lineTo(5.8, 27.8)..lineTo(5.8, 33)
      ..cubicTo(9.2, 39.8, 16.1, 44, 24, 44)..close());
    draw(const Color(0xFFFBBC05), Path()
      ..moveTo(12.6, 27.8)
      ..cubicTo(12.2, 26.6, 12, 25.3, 12, 24)
      ..cubicTo(12, 22.7, 12.2, 21.4, 12.6, 20.2)
      ..lineTo(12.6, 15)..lineTo(5.8, 15)
      ..cubicTo(3.4, 19.7, 3.4, 28.3, 5.8, 33)
      ..lineTo(12.6, 27.8)..close());
    draw(const Color(0xFFEA4335), Path()
      ..moveTo(24, 11.8)
      ..cubicTo(27, 11.8, 29.7, 12.8, 31.8, 14.9)
      ..lineTo(37.6, 9.1)
      ..cubicTo(34.1, 5.9, 29.5, 4, 24, 4)
      ..cubicTo(16.1, 4, 9.2, 8.5, 5.8, 15)
      ..lineTo(12.6, 20.2)
      ..cubicTo(14.2, 15.4, 18.7, 11.8, 24, 11.8)..close());
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}
