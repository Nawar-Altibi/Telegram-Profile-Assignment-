import 'package:flutter/material.dart';

import '../../../../../core/constants/theme/app_text_styles.dart';

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
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 3),
            Text(label, style: AppTextStyles.mediaBadge),
          ],
        ),
      ),
    );
  }
}
