import 'package:flutter/material.dart';

import '../../../enums/profile_tab.dart';
import '../../layout/profile_metrics.dart';
import '../../scroll/profile_scroll_physics.dart';
import '../../view_models/media_item_view_model.dart';
import '../empty/empty_media_view.dart';
import 'media_grid_sliver.dart';

/// One swipeable media page. Kept alive so leaving and returning does not
/// throw away its scroll offset.
class ProfileTabPage extends StatefulWidget {
  const ProfileTabPage({
    super.key,
    required this.tab,
    required this.items,
    required this.metrics,
    required this.onAtEndChanged,
    required this.onItemTap,
  });

  final ProfileTab tab;
  final List<MediaItemViewModel> items;
  final ProfileMetrics metrics;

  /// Reports whether this tab's grid is scrolled to its last row.
  final ValueChanged<bool> onAtEndChanged;
  final void Function(List<MediaItemViewModel> items, int index) onItemTap;

  @override
  State<ProfileTabPage> createState() => _ProfileTabPageState();
}

class _ProfileTabPageState extends State<ProfileTabPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool? _atEnd;

  void _report(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    final atEnd = metrics.extentAfter < 1;
    if (atEnd == _atEnd) return;
    _atEnd = atEnd;
    widget.onAtEndChanged(atEnd);
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0) _report(notification.metrics);
    return false;
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0) _report(notification.metrics);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isArchived = widget.tab == ProfileTab.archived;
    final metrics = widget.metrics;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: _grid(isArchived, metrics),
      ),
    );
  }

  Widget _grid(bool isArchived, ProfileMetrics metrics) {
    return CustomScrollView(
      key: PageStorageKey<String>('${widget.tab.name}-grid'),
      physics: ProfileScrollBehavior.physics,
      slivers: <Widget>[
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 2)),
        if (isArchived) const SliverToBoxAdapter(child: ArchivedNotice()),
        if (widget.items.isEmpty)
          SliverToBoxAdapter(
            child: EmptyMediaView(
              title: isArchived ? 'Nothing archived' : 'No posts yet...',
              body: isArchived
                  ? 'Stories you archive will be kept here.'
                  : 'Publish photos and videos to display on your profile page',
            ),
          )
        else
          MediaGridSliver(
            items: widget.items,
            metrics: metrics,
            onItemTap: (index) => widget.onItemTap(widget.items, index),
          ),
        // The floating controls are painted over this list, not beside it.
        SliverPadding(
          padding: EdgeInsets.only(bottom: metrics.floatingControlsClearance),
        ),
      ],
    );
  }
}
