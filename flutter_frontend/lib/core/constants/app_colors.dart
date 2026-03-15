import 'package:flutter/material.dart';

/// TabClaim color palette.
/// Philosophy: clean white base, one warm accent, functional neutrals.
/// No gradients. Subtle, premium feel.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────

  /// Primary accent — a warm coral/tangerine.
  /// Used for CTAs, active states, claim confirmations.
  static const Color primary = Color(0xFFFF6B4A);
  static const Color primaryLight = Color(0xFFFF8E72);
  static const Color primaryMuted = Color(0xFFFFEDE9);

  // ── Surface / Background ───────────────────────────────────────────────────

  static const Color background = Color(0xFFF9F9F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F3F1);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // ── Neutrals ───────────────────────────────────────────────────────────────

  static const Color ink = Color(0xFF1A1A1A);        // headings, primary text
  static const Color inkSecondary = Color(0xFF6B6B6B); // captions, labels
  static const Color inkMuted = Color(0xFFB0B0B0);    // placeholders, disabled
  static const Color divider = Color(0xFFECECEB);

  // ── Semantic ───────────────────────────────────────────────────────────────

  static const Color success = Color(0xFF34C759);   // claimed / settled
  static const Color successMuted = Color(0xFFEAF8ED);
  static const Color warning = Color(0xFFFF9F0A);   // unassigned items
  static const Color warningMuted = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFFF3B30);

  // ── Participant avatar palette (auto-assigned) ─────────────────────────────

  static const List<Color> avatarColors = [
    Color(0xFFFF6B4A), // coral
    Color(0xFF5E5CE6), // indigo
    Color(0xFF34C759), // mint
    Color(0xFFFF9F0A), // amber
    Color(0xFF30B0C7), // teal
    Color(0xFFBF5AF2), // purple
    Color(0xFFFF375F), // rose
    Color(0xFF32ADE6), // sky
  ];

  static Color avatarColorForIndex(int index) =>
      avatarColors[index % avatarColors.length];
}
