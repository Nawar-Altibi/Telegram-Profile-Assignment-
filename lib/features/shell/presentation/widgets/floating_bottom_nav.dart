import 'package:flutter/material.dart';

import '../../../../core/constants/theme/app_colors.dart';
import '../../../../core/constants/theme/app_text_styles.dart';
import '../../../../core/utils/count_formatter.dart';
import '../../../../core/widgets/frosted_surface.dart';
import '../../../profile/presentation/layout/profile_metrics.dart';

/// One destination of the floating navigation bar.
@immutable
class BottomNavDestination {
  const BottomNavDestination({
    required this.label,
    required this.icon,
    this.badgeCount,
    this.avatar,
  });

  final String label;
  final IconData icon;
  final int? badgeCount;

  /// When set, the destination shows the profile photo instead of [icon].
  final ImageProvider? avatar;
}

/// Translucent floating navigation bar that content scrolls behind.
class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.height,
  });

  final List<BottomNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;

  /// Gap between the bar's edge and the selection pill, matching the
  /// Posts / Archived selector.
  static const double _inset = 4;
  static const Duration _slide = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    return FrostedSurface(
      borderRadius: BorderRadius.circular(height / 2),
      blurSigma: 22,
      tint: const Color(0x991A242E),
      borderColor: Colors.white.withValues(alpha: 0.06),
      // The bar grows with the text scale only up to ProfileMetrics'
      // navMaxTextScale; past that the labels would push the icons out of a
      // control that has to stay reachable with a thumb.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: ProfileMetrics.navMaxTextScale,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(_inset),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double itemWidth =
                    constraints.maxWidth / destinations.length;
                return Stack(
                  children: <Widget>[
                    AnimatedPositionedDirectional(
                      duration: _slide,
                      curve: Curves.easeOutCubic,
                      start: itemWidth * selectedIndex,
                      width: itemWidth,
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.tabSelected,
                          borderRadius: BorderRadius.circular(
                            height / 2 - _inset,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        for (var i = 0; i < destinations.length; i++)
                          Expanded(
                            child: _NavItem(
                              destination: destinations[i],
                              isSelected: i == selectedIndex,
                              onTap: () => onSelected(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final BottomNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.accentSoft : AppColors.secondaryText;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            height: 26,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                if (destination.avatar case final ImageProvider avatar)
                  _Avatar(avatar: avatar)
                else
                  Icon(destination.icon, size: 24, color: color),
                if (destination.badgeCount case final int count when count > 0)
                  PositionedDirectional(
                    top: ProfileMetrics.navBadgeTop,
                    start: ProfileMetrics.navBadgeStart,
                    child: _Badge(count: count),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: AppTextStyles.navLabel.copyWith(color: color),
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatar});

  final ImageProvider avatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(image: avatar, fit: BoxFit.cover),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.badge,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.badgeBorder, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
        child: Text(
          formatCompactCount(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
