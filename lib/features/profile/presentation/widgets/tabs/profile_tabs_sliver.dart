import 'package:flutter/material.dart';

import '../../../../../core/constants/theme/app_colors.dart';
import '../../layout/profile_metrics.dart';
import 'segmented_tabs.dart';

/// Pins the segment selector directly under the collapsed app bar while the
/// information card and the media grid scroll behind it.
class ProfileTabsSliver extends StatelessWidget {
  const ProfileTabsSliver({super.key, required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabsDelegate(
        height: ProfileMetrics.tabsBarHeight,
        controller: controller,
      ),
    );
  }
}

/// Fixed-height pinned header; the opaque background hides the content
/// scrolling underneath it.
class _TabsDelegate extends SliverPersistentHeaderDelegate {
  const _TabsDelegate({required this.height, required this.controller});

  final double height;
  final TabController controller;

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(_TabsDelegate oldDelegate) =>
      oldDelegate.controller != controller || oldDelegate.height != height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return ColoredBox(
      color: AppColors.scaffold,
      child: Center(child: SegmentedTabs(controller: controller)),
    );
  }
}
