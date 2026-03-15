import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).valueOrNull;
    final settings = ref.watch(settingsProvider).valueOrNull;
    final currency = settings?.currency ?? 'USD';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.base,
        ),
        children: [
          // ── Account section ──────────────────────────────────────────────
          _SectionHeader(label: 'Account'),
          if (auth != null && auth.isAuthenticated) ...[
            _InfoTile(
              icon: Icons.person_outline_rounded,
              title: auth.user!.displayName,
              subtitle: auth.user!.email,
            ),
            _ActionTile(
              icon: Icons.logout_rounded,
              label: 'Log out',
              color: AppColors.error,
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go(AppRoutes.auth);
              },
            ),
          ] else ...[
            _ActionTile(
              icon: Icons.login_rounded,
              label: 'Sign in or create account',
              onTap: () => context.push(AppRoutes.auth),
            ),
          ],

          const SizedBox(height: AppSpacing.base),

          // ── App settings section ─────────────────────────────────────────
          _SectionHeader(label: 'Currency'),
          ...supportedCurrencies.map(
            (c) => _CurrencyTile(
              code: c.code,
              label: c.label,
              symbol: c.symbol,
              selected: currency == c.code,
              onTap: () =>
                  ref.read(settingsProvider.notifier).setCurrency(c.code),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.sm,
        AppSpacing.screenPaddingH,
        AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.inkMuted,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: 2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.inkSecondary),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyMedium),
                Text(subtitle,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.inkSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: 2,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: effectiveColor),
                const SizedBox(width: AppSpacing.base),
                Text(label,
                    style: AppTypography.body
                        .copyWith(color: effectiveColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({
    required this.code,
    required this.label,
    required this.symbol,
    required this.selected,
    required this.onTap,
  });
  final String code;
  final String label;
  final String symbol;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: 2,
      ),
      child: Material(
        color: selected ? AppColors.primaryMuted : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    symbol,
                    style: AppTypography.bodyMedium.copyWith(
                      color: selected
                          ? AppColors.primary
                          : AppColors.inkSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '$code — $label',
                    style: AppTypography.body.copyWith(
                      color: selected ? AppColors.primary : AppColors.ink,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded,
                      size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
