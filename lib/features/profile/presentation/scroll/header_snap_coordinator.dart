import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'profile_scroll_physics.dart';

/// Settles the header when a gesture ends part-way through a transition.
///
/// Two ranges of the outer scroll are transitions rather than places to
/// stop:
///
///  * the cover gallery, between offset 0 (open) and [galleryRange]
///    (resting), animated to whichever end it is closer to - the same
///    behaviour the reference shows when the pull is abandoned;
///  * the swallow, between [galleryRange] and [swallowOffset], where the
///    avatar is either pulled the rest of the way into the hole or let back
///    out to its resting place, whichever it is nearer.
class HeaderSnapCoordinator {
  HeaderSnapCoordinator({required this.controller});

  final ScrollController controller;

  double galleryRange = 0;

  /// Offset at which the avatar is fully swallowed.
  double swallowOffset = 0;

  static const double _minSnapMillis = 260;
  static const double _maxSnapMillis = 460;
  static const double _millisPerPixel = 0.6;

  /// Bounds of the tap-driven open, which starts from a standstill and so
  /// eases in as well as out.
  static const int _minOpenMillis = 380;
  static const int _maxOpenMillis = 560;
  static const double _openMillisPerPixel = 0.9;

  bool _pending = false;
  double _releaseVelocity = 0;

  /// Morphs the header into the full-width cover, as tapping the avatar does.
  ///
  /// Does nothing when the cover is already open, so a tap on the open photo
  /// is ignored.
  void openCover() {
    if (!controller.hasClients) return;
    final double offset = controller.position.pixels;
    if (offset < 0.5) return;
    final int millis = (_minOpenMillis + offset * _openMillisPerPixel)
        .clamp(_minOpenMillis, _maxOpenMillis)
        .round();
    controller.animateTo(
      0,
      duration: Duration(milliseconds: millis),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Feed every [ScrollNotification] from the outer profile list through this.
  ///
  /// Inner tab scrolls bubble with `depth > 0` and are ignored. A ballistic
  /// release is normally settled by [ProfileScrollPhysics]; this runs only
  /// when a gesture ends with the header still parked inside a transition.
  bool handleNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollEndNotification) {
      // Finger-down is positive primaryVelocity; scroll physics uses the
      // opposite sign (negative opens the gallery).
      final primary = notification.dragDetails?.primaryVelocity;
      _releaseVelocity = primary == null ? 0 : -primary;
      _schedule();
    }
    return false;
  }

  void _schedule() {
    if (_pending) return;
    _pending = true;
    // Deferred so the animation is not started from inside the notification
    // dispatch that ended the previous scroll activity.
    scheduleMicrotask(() {
      _pending = false;
      _settle();
    });
  }

  void _settle() {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (position.isScrollingNotifier.value) return;
    final offset = position.pixels;

    final double? target;
    if (galleryRange > 0 && offset > 0 && offset < galleryRange) {
      target = ProfileScrollPhysics.snapTarget(
        pixels: offset,
        velocity: _releaseVelocity,
        restingOffset: galleryRange,
      );
    } else if (swallowOffset > galleryRange &&
        offset > galleryRange &&
        offset < swallowOffset) {
      target = ProfileScrollPhysics.swallowSnapTarget(
        pixels: offset,
        velocity: _releaseVelocity,
        restingOffset: galleryRange,
        swallowOffset: math.min(swallowOffset, position.maxScrollExtent),
      );
    } else {
      target = null;
    }
    if (target == null) return;

    final distance = (offset - target).abs();
    if (distance < 0.5) return;

    // Duration tracks how far the header still has to travel; the curve
    // glides in without overshoot so the morph never jolts at the end.
    final millis = (_minSnapMillis + distance * _millisPerPixel)
        .clamp(_minSnapMillis, _maxSnapMillis)
        .round();
    controller.animateTo(
      target,
      duration: Duration(milliseconds: millis),
      curve: Curves.easeOutCubic,
    );
  }
}
