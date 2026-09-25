import 'package:flutter/material.dart';

import '../../../../core/constants/theme/app_colors.dart';
import '../../../../core/widgets/frosted_surface.dart';

/// The floating "Add a post" pill. The accent fill is translucent so the
/// grid blurs through it the same way it does through the navigation bar.
class AddPostButton extends StatelessWidget {
  const AddPostButton({super.key, this.onPressed, this.opacity = 1});

  final VoidCallback? onPressed;

  /// Folded into the tint, the blur and the label so the button can fade
  /// without an [Opacity] layer over its backdrop filter.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final Color content = Colors.white.withValues(alpha: opacity);
    return FrostedSurface(
      borderRadius: BorderRadius.circular(21),
      blurSigma: 18,
      opacity: opacity,
      tint: AppColors.accent.withValues(alpha: 0.72),
      borderColor: AppColors.scaffold,
      borderWidth: 2,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.photo_camera_rounded, size: 19, color: content),
                const SizedBox(width: 7),
                Text(
                  'Add a post',
                  style: TextStyle(
                    color: content,
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
