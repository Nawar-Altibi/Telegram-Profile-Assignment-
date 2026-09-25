import 'package:flutter/material.dart';

import '../../../../../core/constants/theme/app_colors.dart';
import '../../../../../core/constants/theme/app_text_styles.dart';
import '../../../../../core/widgets/frosted_surface.dart';
import '../../layout/profile_metrics.dart';

/// Immutable description of one header action button.
@immutable
class HeaderAction {
  const HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// The Set Photo / Edit Info / Settings row.
///
/// The row is anchored to the bottom edge of the header in every state; the
/// header only squashes and fades it on the way to the app bar. That is why
/// this widget can be built once and reused for the whole scroll. Each button
/// is frosted, so over the open cover the photo blurs through it; the buttons
/// never overlap, so they share a single backdrop capture.
class HeaderActions extends StatefulWidget {
  const HeaderActions({
    super.key,
    required this.actions,
    this.frosted = true,
    this.opacity = 1,
  });

  final List<HeaderAction> actions;

  /// Blur the backdrop. Only worth it while the cover photo is behind the
  /// row; over the plain header gradient a blur is invisible.
  final bool frosted;

  /// Folded into the tint and the label colours rather than applied as an
  /// [Opacity] layer.
  final double opacity;

  @override
  State<HeaderActions> createState() => _HeaderActionsState();
}

class _HeaderActionsState extends State<HeaderActions> {
  final BackdropKey _backdrop = BackdropKey();

  @override
  Widget build(BuildContext context) {
    final List<HeaderAction> actions = widget.actions;
    return BackdropGroup(
      backdropKey: _backdrop,
      child: SizedBox(
        height: ProfileMetrics.actionsHeight,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < actions.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: ProfileMetrics.actionsGap),
              Expanded(
                child: _ActionButton(
                  action: actions[i],
                  frosted: widget.frosted,
                  opacity: widget.opacity,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One icon-over-label tile of the action row, either frosted (over the
/// photo) or tint-only (over the plain gradient).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.frosted,
    required this.opacity,
  });

  final HeaderAction action;
  final bool frosted;
  final double opacity;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final bool faded = opacity < 1;
    final Color iconColor = faded
        ? AppColors.primaryText.withValues(
            alpha: AppColors.primaryText.a * opacity,
          )
        : AppColors.primaryText;
    final TextStyle labelStyle = faded
        ? AppTextStyles.actionLabel.copyWith(color: iconColor)
        : AppTextStyles.actionLabel;
    return FrostedSurface(
      borderRadius: _radius,
      blurSigma: 22,
      blur: frosted,
      opacity: opacity,
      tint: const Color(0x2E000000),
      borderColor: Colors.white.withValues(alpha: 0.08),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: _radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(action.icon, size: 22, color: iconColor),
                  const SizedBox(height: 5),
                  Text(
                    action.label,
                    style: labelStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
