import 'package:flutter/material.dart';

import '../../../../../core/constants/theme/app_colors.dart';
import '../../../../../core/constants/theme/app_text_styles.dart';
import '../../layout/profile_metrics.dart';

/// Translucent pill used for the view counter and the clip duration.
///
/// Telegram keeps it barely visible on dark thumbnails and clearly readable
/// on light ones, which a single low-alpha black pill achieves for free.
class MediaBadge extends StatelessWidget {
  const MediaBadge({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mediaBadge,
        borderRadius: BorderRadius.circular(ProfileMetrics.mediaBadgeRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ProfileMetrics.mediaBadgeHorizontalPadding,
          vertical: ProfileMetrics.mediaBadgeVerticalPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: ProfileMetrics.mediaBadgeIconSize,
              color: AppColors.mediaOverlayIcon,
            ),
            const SizedBox(width: ProfileMetrics.mediaBadgeIconGap),
            Text(label, style: AppTextStyles.mediaBadge),
          ],
        ),
      ),
    );
  }
}
