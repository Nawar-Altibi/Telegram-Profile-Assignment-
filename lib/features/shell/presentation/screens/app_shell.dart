import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/theme/app_colors.dart';
import '../../../../core/widgets/floating_notice.dart';
import '../../../profile/enums/profile_tab.dart';
import '../../../profile/presentation/controller/profile_controller.dart';
import '../../../profile/presentation/layout/profile_metrics.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../profile/presentation/view_models/profile_view_model.dart';
import '../widgets/add_post_button.dart';
import '../widgets/floating_bottom_nav.dart';

/// Hosts the profile page and the floating controls that sit above it.
///
/// The controls live here, outside the scroll view, so page content scrolls
/// behind the blurred bar instead of stopping short of it. Only the profile
/// is part of this assignment; the other destinations show a notice.
///
/// The shell rebuilds only when the profile data changes. Tab switches go
/// through [ProfileController.tabListenable], which nothing here listens to.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const int _profileIndex = 3;

  final ProfileController _controller = ProfileController();

  /// False while the profile opens on its full cover photo; the add-post
  /// button only appears once the posts start scrolling into view.
  final ValueNotifier<bool> _profileContentVisible = ValueNotifier<bool>(false);

  /// Notices float above the controls; the page raises them through the
  /// [NoticeScope] this shell provides.
  final NoticeController _notice = NoticeController();

  /// Shared by the add-post button, the notice and the bottom bar. They never
  /// overlap and all float over the finished page, so one capture serves all.
  final BackdropKey _floatingBackdrop = BackdropKey();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _profileContentVisible.dispose();
    _notice.dispose();
    super.dispose();
  }

  List<BottomNavDestination> _destinations(ProfileViewModel profile) =>
      <BottomNavDestination>[
        BottomNavDestination(
          label: 'Chats',
          icon: Icons.chat_bubble_outline_rounded,
          badgeCount: profile.unreadChatCount,
        ),
        const BottomNavDestination(
          label: 'Contacts',
          icon: Icons.account_circle_outlined,
        ),
        const BottomNavDestination(
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
        BottomNavDestination(
          label: 'Profile',
          icon: Icons.person_rounded,
          avatar: profile.avatar,
        ),
      ];

  void _onDestinationSelected(ProfileViewModel profile, int index) {
    if (index == _profileIndex) return;
    final BottomNavDestination destination = _destinations(profile)[index];
    HapticFeedback.selectionClick();
    _notice.show(
      icon: destination.icon,
      title: destination.label,
      message: 'This page is not available yet',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.scaffold,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final profile = _controller.profile;
            if (profile == null) return const SizedBox.shrink();

            final metrics = ProfileMetrics.of(context);
            final navMargin = metrics.floatingHorizontalMargin;

            return NoticeScope(
              controller: _notice,
              child: BackdropGroup(
                backdropKey: _floatingBackdrop,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: ProfileScreen(
                        profile: profile,
                        mediaByTab: {
                          for (final tab in ProfileTab.values)
                            tab: _controller.mediaFor(tab),
                        },
                        tab: _controller.tab,
                        onTabChanged: _controller.selectTab,
                        contentVisible: _profileContentVisible,
                      ),
                    ),
                    // The notice stacks on top of the add-post slot, so it never
                    // covers the button or the bar whatever their sizes.
                    Positioned(
                      left: navMargin,
                      right: navMargin,
                      bottom: metrics.floatingStackBottom,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          FloatingNotice(notice: _notice),
                          ValueListenableBuilder<bool>(
                            valueListenable: _profileContentVisible,
                            builder: (context, shown, child) {
                              return IgnorePointer(
                                ignoring: !shown,
                                child: AnimatedSlide(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  offset: shown
                                      ? Offset.zero
                                      : const Offset(0, 1.6),
                                  // Faded through the button's own tint: an
                                  // opacity layer would hide the grid from its
                                  // blur.
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(end: shown ? 1 : 0),
                                    duration: const Duration(milliseconds: 180),
                                    builder: (context, opacity, _) =>
                                        AddPostButton(opacity: opacity),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: navMargin,
                      right: navMargin,
                      bottom: metrics.navBottom,
                      child: FloatingBottomNav(
                        height: metrics.bottomNavHeight,
                        selectedIndex: _profileIndex,
                        onSelected: (index) =>
                            _onDestinationSelected(profile, index),
                        destinations: _destinations(profile),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
