import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../enums/profile_tab.dart';
import '../layout/profile_metrics.dart';

/// Turns the profile's scroll notifications into the two values the header
/// listens to, so neither goes through a `setState` on the screen:
///
///  * [stretch] - pull past the open cover. The nested scroll view does not
///    stretch the pinned header, so this is applied on top of the header
///    geometry, then eased back to zero once the finger lifts.
///  * [atPageEnd] - true only while both the outer list and the visible tab
///    are scrolled to their end, which is when the status line shows the
///    story count.
class ProfileScrollCoordinator {
  ProfileScrollCoordinator({
    required TickerProvider vsync,
    required ProfileTab Function() currentTab,
  }) : _currentTab = currentTab {
    _release = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 240),
    )..addListener(_tickRelease);
  }

  final ProfileTab Function() _currentTab;

  final ValueNotifier<double> stretch = ValueNotifier<double>(0);
  final ValueNotifier<bool> atPageEnd = ValueNotifier<bool>(false);

  /// Eases the stretch back to zero after the finger lifts. Time based, so
  /// the release takes the same time at 60 Hz and 120 Hz.
  late final AnimationController _release;
  double _releaseFrom = 0;

  bool _outerAtEnd = false;
  final Map<ProfileTab, bool> _innerAtEnd = <ProfileTab, bool>{};
  bool _disposed = false;

  /// Feed every notification from above the outer scroll view. Never
  /// consumes the notification.
  void handleNotification(ScrollNotification notification) {
    if (notification.depth != 0) return;
    _trackStretch(notification);
    _trackOuterEnd(notification);
  }

  /// Reports whether [tab]'s grid is scrolled to its last row.
  void setTabAtEnd(ProfileTab tab, bool atEnd) {
    _innerAtEnd[tab] = atEnd;
    syncPageEnd();
  }

  /// Re-evaluates [atPageEnd], e.g. after the visible tab changed.
  void syncPageEnd() {
    final tab = _currentTab();
    publish(atPageEnd, _outerAtEnd && (_innerAtEnd[tab] ?? true));
  }

  /// Scroll notifications and controller ticks can arrive during layout,
  /// where notifying listeners would rebuild widgets mid-frame.
  void publish(ValueNotifier<bool> notifier, bool value) {
    if (notifier.value == value) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifier.value = value;
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifier.value = value;
    });
  }

  /// The outer list reaches its end first, then the visible tab's grid takes
  /// over; the page is at its end only when both have run out.
  void _trackOuterEnd(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return;
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return;
    }
    _outerAtEnd = notification.metrics.extentAfter < 1;
    syncPageEnd();
  }

  /// Grows the cover while the finger pulls past offset 0, then lets the
  /// value fall back when the gesture ends.
  void _trackStretch(ScrollNotification notification) {
    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.metrics.pixels <= 0) {
      _release.stop();
      stretch.value = math.min(
        ProfileMetrics.maxStretch,
        stretch.value - notification.overscroll,
      );
      return;
    }
    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels < 0) {
      _release.stop();
      stretch.value = math.min(
        ProfileMetrics.maxStretch,
        -notification.metrics.pixels,
      );
      return;
    }
    if (notification is ScrollEndNotification && stretch.value > 0) {
      _releaseFrom = stretch.value;
      _release.forward(from: 0);
    }
  }

  void _tickRelease() {
    final double t = Curves.easeOutCubic.transform(_release.value);
    stretch.value = _releaseFrom * (1 - t);
  }

  void dispose() {
    _disposed = true;
    _release.dispose();
    stretch.dispose();
    atPageEnd.dispose();
  }
}
