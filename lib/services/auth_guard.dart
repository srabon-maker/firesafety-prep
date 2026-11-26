import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';
import '../screens/login_page.dart';

class AuthGuard {
  AuthGuard._();

  static Future<bool> ensureAuthenticated(
    BuildContext context,
  ) async {
    try {
      // Check existing server session.
      final session =
          await AuthService.instance.validateSession();

      if (!context.mounted) return false;

      if (session != null) {
        return true;
      }

      // No valid session: open Login screen.
      final loginSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
      );

      if (!context.mounted || loginSuccess != true) {
        return false;
      }

      // Verify the newly created server session.
      final newSession =
          await AuthService.instance.validateSession();

      if (!context.mounted) return false;

      return newSession != null;
    } catch (e) {
      if (!context.mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is PlatformException
                ? 'Login যাচাই করা যায়নি। অ্যাপটি আবার চালু করে চেষ্টা করুন।'
                : 'Login যাচাই করা যায়নি: ${e.toString().replaceFirst('Exception: ', '')}',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return false;
    }
  }
}
