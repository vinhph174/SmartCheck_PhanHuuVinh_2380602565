import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'config/app_theme.dart';
import 'config/display_text.dart';
import 'screens/common/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();
  runApp(const SmartCheckApp());
}

class SmartCheckApp extends StatelessWidget {
  const SmartCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: DisplayText.appNameTitleCase,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
