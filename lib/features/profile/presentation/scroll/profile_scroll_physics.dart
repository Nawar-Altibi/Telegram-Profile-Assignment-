import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// One scroll feel for the profile page.
///
/// The outer list and both tab grids read [physics] from here, and
/// [ProfileScrollBehavior] installs it as the ambient default so a new
/// scrollable cannot fall back to the platform clamp.
class ProfileScrollBehavior extends ScrollBehavior {
  const ProfileScrollBehavior();

  static const ScrollPhysics physics = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => physics;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// Bouncing physics that refuse to let momentum open the cover gallery.
///
/// The gallery occupies scroll offsets `[0, restingOffset)`, so as far as the
/// scroll machinery is concerned it is simply more list above the resting
/// state - and a hard fling back to the top would sail straight into it. That
/// is the wrong feel: the reference only opens the cover for a deliberate
/// pull, and landing on a full-screen photo because you flicked back to the
/// top is exactly the kind of thing that makes a header feel out of control.
///
/// A fling that starts below the resting state is therefore given the resting
/// state as its floor. Dragging is untouched, so the gesture that is supposed
/// to open the gallery still does.
///
/// The swallow, `[restingOffset, swallowOffset]`, is not a place to stop
/// either: a gentle release inside it springs to whichever end is nearer, so
/// the avatar is either swallowed or back at rest, never frozen at the hole.
class ProfileScrollPhysics extends ScrollPhysics {
  const ProfileScrollPhysics({
    required this.restingOffset,
    this.swallowOffset = 0,
    super.parent,
  });

  final double restingOffset;

  /// Offset at which the avatar is fully swallowed; no swallow snap when it
  /// is not past [restingOffset].
  final double swallowOffset;

  /// A critically damped spring: it glides into place without bouncing, so
  /// the circle-to-cover morph eases in instead of wobbling at the end.
  static const SpringDescription snapSpring = SpringDescription(
    mass: 0.85,
    stiffness: 320,
    damping: 33,
  );

  /// Finger speed (px/s, scroll-offset convention: negative opens the
  /// gallery) past which the release direction wins over the position.
  static const double snapFlingVelocity = 900;

  /// Where a release inside the gallery should land.
  ///
  /// Velocity only overrides the halfway split once the header is already
  /// most of the way to that end. A fling that merely crosses the resting
  /// line must not throw the cover open.
  static double snapTarget({
    required double pixels,
    required double velocity,
    required double restingOffset,
  }) {
    if (velocity <= -snapFlingVelocity && pixels < restingOffset * 0.72) {
      return 0;
    }
    if (velocity >= snapFlingVelocity && pixels > restingOffset * 0.28) {
      return restingOffset;
    }
    return pixels < restingOffset * 0.5 ? 0 : restingOffset;
  }

  /// Where a release inside the swallow should land: swallowed if the avatar
  /// is nearer the hole than its resting place, back at rest otherwise. A
  /// clear flick decides regardless.
  static double swallowSnapTarget({
    required double pixels,
    required double velocity,
    required double restingOffset,
    required double swallowOffset,
  }) {
    if (velocity >= snapFlingVelocity) return swallowOffset;
    if (velocity <= -snapFlingVelocity) return restingOffset;
    return pixels < (restingOffset + swallowOffset) / 2
        ? restingOffset
        : swallowOffset;
  }

  bool _inSwallow(double pixels) =>
      swallowOffset > restingOffset &&
      pixels > restingOffset &&
      pixels < swallowOffset;

  @override
  ProfileScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ProfileScrollPhysics(
      restingOffset: restingOffset,
      swallowOffset: swallowOffset,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final pixels = position.pixels;
    if (restingOffset > 0 && pixels > 0 && pixels < restingOffset) {
      return ScrollSpringSimulation(
        snapSpring,
        pixels,
        snapTarget(
          pixels: pixels,
          velocity: velocity,
          restingOffset: restingOffset,
        ),
        velocity,
        tolerance: toleranceFor(position),
      );
    }

    // A flick keeps its momentum (up through the swallow into the app bar,
    // or down onto the resting floor below); anything gentler settles.
    if (_inSwallow(pixels) && velocity.abs() < snapFlingVelocity) {
      return ScrollSpringSimulation(
        snapSpring,
        pixels,
        swallowSnapTarget(
          pixels: pixels,
          velocity: velocity,
          restingOffset: restingOffset,
          swallowOffset: math.min(swallowOffset, position.maxScrollExtent),
        ),
        velocity,
        tolerance: toleranceFor(position),
      );
    }

    // Momentum that arrives on the resting line is absorbed there. Letting
    // the parent simulation continue would carry a list fling into the cover.
    if (restingOffset > 0 && pixels >= restingOffset && velocity < 0) {
      final simulation = super.createBallisticSimulation(position, velocity);
      if (simulation == null || pixels == restingOffset) {
        return ScrollSpringSimulation(
          snapSpring,
          pixels,
          restingOffset,
          0,
          tolerance: toleranceFor(position),
        );
      }
      return _FlooredSimulation(simulation, restingOffset);
    }

    return super.createBallisticSimulation(position, velocity);
  }
}

/// Runs [inner] until it would go below [floor], then stops dead on it.
class _FlooredSimulation extends Simulation {
  _FlooredSimulation(this.inner, this.floor)
    : super(tolerance: inner.tolerance);

  final Simulation inner;
  final double floor;

  @override
  double x(double time) => math.max(floor, inner.x(time));

  @override
  double dx(double time) => inner.x(time) <= floor ? 0 : inner.dx(time);

  @override
  bool isDone(double time) => inner.x(time) <= floor || inner.isDone(time);
}
