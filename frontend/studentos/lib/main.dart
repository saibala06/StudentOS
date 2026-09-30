import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: StudentOSApp()));
}

class StudentOSApp extends StatelessWidget {
  const StudentOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudentOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
