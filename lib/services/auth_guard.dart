import 'package:flutter/material.dart';

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
            'Login যাচাই করা যায়নি: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return false;
    }
  }
}
