import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/tab_claim_wordmark.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 1800)),
      ref.read(authProvider.future),
    ]);
    if (!mounted) return;
    final auth = results[1] as AuthState;
    context.go(auth.hasSession ? AppRoutes.home : AppRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TabClaimWordmark(fontSize: 48)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(
                  begin: 0.15,
                  end: 0,
                  duration: 400.ms,
                  curve: Curves.easeOut,
                ),
            const SizedBox(height: 10),
            Text(
              'Dinner with friends, math handled.',
              style: AppTypography.body
                  .copyWith(color: AppColors.inkSecondary),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
