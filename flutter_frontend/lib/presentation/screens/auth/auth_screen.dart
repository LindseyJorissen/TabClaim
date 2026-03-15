import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../providers/auth_provider.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
            vertical: AppSpacing.screenPaddingV,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // ── Wordmark ─────────────────────────────────────────────────
              Image.asset(
                'assets/icons/logo_with_text.png',
                height: 64,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Split the bill,\nnot the mood.', style: AppTypography.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Scan any receipt, claim your items, and see exactly what everyone owes.',
                style: AppTypography.body.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
              const Spacer(),
              // ── Actions ─────────────────────────────────────────────────
              ElevatedButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).continueAsGuest();
                  if (context.mounted) context.go(AppRoutes.home);
                },
                child: const Text('Continue as guest'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => context.push(AppRoutes.register),
                child: const Text('Create account'),
              ),
              const SizedBox(height: AppSpacing.base),
              Center(
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.login),
                  child: Text(
                    'Already have an account? Sign in',
                    style: AppTypography.captionMedium.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}
