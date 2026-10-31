
import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FireSafetyJobPrepApp());
}

class FireSafetyJobPrepApp extends StatelessWidget {
  const FireSafetyJobPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fire Safety BD',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
