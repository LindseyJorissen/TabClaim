import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/participant.dart';

class ParticipantAvatar extends StatelessWidget {
  const ParticipantAvatar({
    super.key,
    required this.participant,
    this.size = AppSpacing.participantAvatarSize,
    this.isSelected = false,
    this.showBadge = false,
    this.badgeIcon,
  });

  final Participant participant;
  final double size;
  final bool isSelected;
  final bool showBadge;
  final IconData? badgeIcon;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.avatarColorForIndex(participant.colorIndex);
    final initials = _initials(participant.name);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: isSelected
            ? Border.all(color: color, width: 2.5)
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: participant.emoji != null
                ? Text(
                    participant.emoji!,
                    style: TextStyle(fontSize: size * 0.42),
                  )
                : Text(
                    initials,
                    style: AppTypography.captionMedium.copyWith(
                      color: color,
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          if (showBadge && badgeIcon != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.36,
                height: size * 0.36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: Icon(
                  badgeIcon,
                  color: Colors.white,
                  size: size * 0.22,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
