import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// "Tab" in dark ink + "Claim" in coral — used on splash and auth screens.
class TabClaimWordmark extends StatelessWidget {
  const TabClaimWordmark({super.key, this.fontSize = 40});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
          height: 1.0,
        ),
        children: [
          TextSpan(
            text: 'Tab',
            style: TextStyle(color: AppColors.ink),
          ),
          TextSpan(
            text: 'Claim',
            style: TextStyle(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
