import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';

const _kOnboardingDone = 'onboarding_complete';

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDone) ?? false;
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDone, true);
}

// ── Page data ─────────────────────────────────────────────────────────────────

class _Page {
  const _Page({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bgTop,
    required this.bgBottom,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgTop;
  final Color bgBottom;
}

const _pages = [
  _Page(
    icon: Icons.document_scanner_outlined,
    title: 'Scan the receipt',
    subtitle: 'Point your camera at any receipt. TabClaim reads the items for you instantly.',
    bgTop: Color(0xFFFF8C5A),
    bgBottom: Color(0xFFFF6B4A),
  ),
  _Page(
    icon: Icons.touch_app_outlined,
    title: 'Claim what you had',
    subtitle: 'Tap each item to assign it. Split shared dishes between people in one tap.',
    bgTop: Color(0xFFFFAA6B),
    bgBottom: Color(0xFFFF8C5A),
  ),
  _Page(
    icon: Icons.account_balance_wallet_outlined,
    title: 'See who owes what',
    subtitle: 'TabClaim does the math and shows exactly who pays who. No spreadsheets needed.',
    bgTop: Color(0xFFFF6B4A),
    bgBottom: Color(0xFFE85A38),
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    await markOnboardingDone();
    if (mounted) context.go(AppRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [page.bgTop, page.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Skip ──────────────────────────────────────────────────
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: AppSpacing.screenPaddingH,
                    top: AppSpacing.sm,
                  ),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: AppTypography.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Pages ─────────────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _pages.length,
                  itemBuilder: (context, i) => _OnboardingPage(page: _pages[i]),
                ),
              ),

              // ── Dots ──────────────────────────────────────────────────
              _Dots(count: _pages.length, current: _page),
              const SizedBox(height: AppSpacing.xl),

              // ── CTA ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingH,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: page.bgBottom,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _next,
                    child: Text(
                      _page == _pages.length - 1 ? 'Get started' : 'Next',
                      style: AppTypography.button.copyWith(color: page.bgBottom),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single page ───────────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page});
  final _Page page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Brand mark ──────────────────────────────────────────────
          Image.asset(
            'assets/icons/logo_with_text.png',
            height: 72,
            fit: BoxFit.contain,
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.1, end: 0, duration: 400.ms),

          const SizedBox(height: AppSpacing.xxl),

          // ── Step icon ────────────────────────────────────────────────
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 38, color: Colors.white),
          )
              .animate()
              .scale(duration: 500.ms, curve: Curves.easeOutBack)
              .fadeIn(delay: 50.ms, duration: 300.ms),

          const SizedBox(height: AppSpacing.xl),

          // ── Title ────────────────────────────────────────────────────
          Text(
            page.title,
            style: AppTypography.h1.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 300.ms)
              .slideY(begin: 0.15, end: 0, delay: 100.ms, duration: 300.ms),

          const SizedBox(height: AppSpacing.base),

          // ── Subtitle ─────────────────────────────────────────────────
          Text(
            page.subtitle,
            style: AppTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 150.ms, duration: 300.ms)
              .slideY(begin: 0.15, end: 0, delay: 150.ms, duration: 300.ms),
        ],
      ),
    );
  }
}

// ── Dot indicators ────────────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
        );
      }),
    );
  }
}
