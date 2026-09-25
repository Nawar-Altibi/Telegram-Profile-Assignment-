import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/floating_notice.dart';
import '../../enums/profile_tab.dart';
import '../layout/header_geometry.dart';
import '../layout/media_images.dart';
import '../layout/profile_metrics.dart';
import '../scroll/header_snap_coordinator.dart';
import '../scroll/profile_scroll_coordinator.dart';
import '../scroll/profile_scroll_physics.dart';
import '../view_models/media_item_view_model.dart';
import '../view_models/profile_view_model.dart';
import '../widgets/grid/profile_tab_page.dart';
import '../widgets/header/header_actions.dart';
import '../widgets/header/pinned_obstruction.dart';
import '../widgets/header/profile_header_sliver.dart';
import '../widgets/info/profile_info_card.dart';
import '../widgets/tabs/profile_tabs_sliver.dart';
import 'story_preview.dart';

/// The scrolling half of the profile page.
///
/// The floating controls are owned by the shell above this widget. The header
/// and the tab strip live in a [NestedScrollView] so each tab keeps its own
/// scroll position and the user can swipe between them.
///
/// Scroll model
/// ------------
/// The header sliver's `maxExtent` is the fully open cover gallery, but the
/// outer list starts at `metrics.galleryRange`, so the screen opens on the
/// resting state and the gallery is reached by pulling the list down past its
/// top.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.mediaByTab,
    required this.tab,
    required this.onTabChanged,
    this.contentVisible,
  });

  final ProfileViewModel profile;
  final Map<ProfileTab, List<MediaItemViewModel>> mediaByTab;
  final ProfileTab tab;
  final ValueChanged<ProfileTab> onTabChanged;

  /// Set to false while the cover photo fills the header and true once the
  /// user has scrolled down towards the posts. The shell uses it to show the
  /// add-post button only when there is content under it.
  final ValueNotifier<bool>? contentVisible;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  ScrollController? _scrollController;
  HeaderSnapCoordinator? _snap;
  ProfileMetrics? _metrics;
  ProfileScrollPhysics? _physics;

  /// Overscroll stretch and page-end state, fed from scroll notifications.
  late final ProfileScrollCoordinator _scroll = ProfileScrollCoordinator(
    vsync: this,
    currentTab: () => ProfileTab.values[_tabs.index],
  );

  /// Reused across scroll frames and tab changes. The header widget identity
  /// stays put so switching Posts / Archived does not rebuild it.
  ProfileHeaderSliver? _header;
  Widget? _infoCard;
  int? _headerStamp;

  late final TabController _tabs = TabController(
    length: ProfileTab.values.length,
    vsync: this,
    initialIndex: ProfileTab.values.indexOf(widget.tab),
  );

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_handleTabTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final previous = _metrics;
    final metrics = ProfileMetrics.of(context);
    _metrics = metrics;

    if (_scrollController == null) {
      _attachController(0);
      precacheImage(widget.profile.avatar, context);
    } else if (previous != null && previous != metrics) {
      if (previous.galleryRange != metrics.galleryRange) {
        _reanchor(from: previous, to: metrics);
      }
      _physics = _physicsFor(metrics);
    }
    _snap!
      ..galleryRange = metrics.galleryRange
      ..swallowOffset = HeaderGeometry.swallowOffset(metrics);
    _precacheMedia(metrics);
  }

  int? _precachedDecodeWidth;

  /// Rows of each tab warmed before the grid first shows; everything past
  /// them is decoded lazily as the grid builds its tiles.
  static const int _precachedRows = 4;

  /// Warms the providers the first screenful of each tab will ask for, so
  /// the opening grid does not decode on first sight. Repeated only when the
  /// decode size moves (the first real layout on Android, a rotation).
  void _precacheMedia(ProfileMetrics metrics) {
    if (!metrics.isMeasured) return;
    final int width = MediaImages.decodeWidth(
      metrics,
      MediaQuery.devicePixelRatioOf(context),
    );
    if (width == _precachedDecodeWidth) return;
    _precachedDecodeWidth = width;
    final int perTab = metrics.gridColumnCount * _precachedRows;
    final Set<String> assets = <String>{
      for (final List<MediaItemViewModel> items in widget.mediaByTab.values)
        for (final MediaItemViewModel item in items.take(perTab))
          item.assetPath,
    };
    for (final String asset in assets) {
      precacheImage(MediaImages.provider(asset, width), context);
    }
  }

  static ProfileScrollPhysics _physicsFor(ProfileMetrics? metrics) {
    return ProfileScrollPhysics(
      restingOffset: metrics?.galleryRange ?? 0,
      swallowOffset: metrics == null
          ? 0
          : HeaderGeometry.swallowOffset(metrics),
      parent: ProfileScrollBehavior.physics,
    );
  }

  /// Offset `galleryRange` is the resting state and everything above it is
  /// the cover gallery. The page opens at [initialOffset], normally 0: the
  /// photo filling the header.
  void _attachController(double initialOffset) {
    final controller = ScrollController(initialScrollOffset: initialOffset);
    controller.addListener(_syncContentVisible);
    _scrollController = controller;
    _snap = HeaderSnapCoordinator(controller: controller);
    _physics = _physicsFor(_metrics);
  }

  void _syncContentVisible() {
    final visible = widget.contentVisible;
    final controller = _scrollController;
    final metrics = _metrics;
    if (visible == null || controller == null || metrics == null) return;
    if (!controller.hasClients) return;
    _scroll.publish(visible, controller.offset > metrics.galleryRange * 0.5);
  }

  /// Re-anchors the list when the viewport geometry changes underneath it.
  ///
  /// Android reports a 0x0 window for the first frame, so the offset the
  /// controller was born with is routinely stale by the time there is
  /// anything to show.
  void _reanchor({required ProfileMetrics from, required ProfileMetrics to}) {
    final controller = _scrollController!;
    if (!controller.hasClients) {
      controller.dispose();
      _attachController(0);
      return;
    }

    final offset = controller.offset;
    final double anchored;
    if (!from.isMeasured || from.galleryRange <= 0) {
      anchored = 0;
    } else if (offset >= from.galleryRange) {
      anchored = offset - from.galleryRange + to.galleryRange;
    } else {
      anchored = offset / from.galleryRange * to.galleryRange;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      controller.jumpTo(
        anchored.clamp(0.0, controller.position.maxScrollExtent),
      );
    });
  }

  void _handleTabTick() {
    final tab = ProfileTab.values[_tabs.index];
    if (tab != widget.tab) widget.onTabChanged(tab);
    _scroll.syncPageEnd();
  }

  bool _handleScroll(ScrollNotification notification) {
    _scroll.handleNotification(notification);
    return _snap!.handleNotification(notification);
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = ProfileTab.values.indexOf(widget.tab);
    if (_tabs.index != index && !_tabs.indexIsChanging) {
      _tabs.index = index;
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_handleTabTick);
    _tabs.dispose();
    _scroll.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics!;
    _ensureHeader(metrics);
    return ScrollConfiguration(
      behavior: const ProfileScrollBehavior(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: NestedScrollView(
          controller: _scrollController,
          physics: _physics,
          floatHeaderSlivers: false,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            // The absorber has to be the last header sliver: anything after it
            // is laid out underneath the pinned header. Both pinned strips are
            // therefore grouped under it and reported as one obstruction.
            return <Widget>[
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
                sliver: PinnedObstruction(
                  extent:
                      metrics.collapsedExtent + ProfileMetrics.tabsBarHeight,
                  sliver: SliverMainAxisGroup(
                    slivers: <Widget>[
                      _header!,
                      _infoCard!,
                      ProfileTabsSliver(controller: _tabs),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabs,
            children: <Widget>[
              for (final tab in ProfileTab.values)
                ProfileTabPage(
                  key: PageStorageKey<ProfileTab>(tab),
                  tab: tab,
                  items: widget.mediaByTab[tab] ?? const <MediaItemViewModel>[],
                  metrics: metrics,
                  onAtEndChanged: (atEnd) => _scroll.setTabAtEnd(tab, atEnd),
                  onItemTap: (items, index) => _openMedia(items, index),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _ensureHeader(ProfileMetrics metrics) {
    final stamp = Object.hash(widget.profile, metrics);
    if (_header != null && _headerStamp == stamp) return;
    _headerStamp = stamp;
    _header = ProfileHeaderSliver(
      metrics: metrics,
      profile: widget.profile,
      actions: _headerActions(context),
      stretch: _scroll.stretch,
      showStoryCount: _scroll.atPageEnd,
      onAvatarTap: _openCover,
    );
    _infoCard = SliverToBoxAdapter(
      child: RepaintBoundary(
        child: ProfileInfoCard(fields: widget.profile.fields),
      ),
    );
  }

  /// Tapping the circular avatar grows it into the cover photo, the same
  /// morph as pulling the list down; tapping the open cover does nothing.
  void _openCover() => _snap?.openCover();

  void _openMedia(List<MediaItemViewModel> items, int index) {
    StoryPreview.show(
      context,
      assets: <String>[for (final item in items) item.assetPath],
      initialIndex: index,
      onMenuSelected: _notImplemented,
    );
  }

  List<HeaderAction> _headerActions(BuildContext context) {
    HeaderAction action(IconData icon, String label) => HeaderAction(
      icon: icon,
      label: label,
      onTap: () => _notImplemented(icon, label),
    );
    return <HeaderAction>[
      action(Icons.add_a_photo_rounded, 'Set Photo'),
      action(Icons.edit_rounded, 'Edit Info'),
      action(Icons.settings_rounded, 'Settings'),
    ];
  }

  /// Header buttons and preview menu entries lead nowhere in this
  /// assignment; they say so through the shell's floating notice.
  void _notImplemented(IconData icon, String label) {
    HapticFeedback.selectionClick();
    NoticeScope.maybeOf(
      context,
    )?.show(icon: icon, title: label, message: 'Not part of this demo yet');
  }
}
