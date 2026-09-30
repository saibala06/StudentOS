import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'auth/login_screen.dart';
import 'onboarding/onboarding_screen.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      loading: () => const _SplashBody(),
      error: (e, st) => const LoginScreen(),
      data: (user) {
        if (user == null) return const LoginScreen();
        if (!user.onboarded) return const OnboardingScreen();
        return const AppShell();
      },
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.auto_awesome, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('StudentOS', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('AI Academic Assistant', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 28),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
