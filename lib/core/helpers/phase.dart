import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';

/// Maps a global progress value onto a sub-range, the way [Interval] does for
/// animations.
///
/// The header morph is a single scroll-driven value split into several
/// overlapping stages; expressing each stage as `phase(t, start, end)` keeps
/// the timing readable and makes every stage independently tweakable.
double phase(double t, double start, double end) {
  assert(end > start, 'phase() needs a non-empty range');
  return ((t - start) / (end - start)).clamp(0.0, 1.0);
}

/// [phase] with an easing curve applied to the sub-range.
double curvedPhase(double t, double start, double end, Curve curve) {
  return curve.transform(phase(t, start, end));
}

/// Non-nullable [lerpDouble] for the common case of two known doubles.
double lerp(double a, double b, double t) => lerpDouble(a, b, t)!;
