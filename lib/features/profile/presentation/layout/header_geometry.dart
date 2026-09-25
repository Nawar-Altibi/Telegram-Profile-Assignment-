import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../../../../core/helpers/phase.dart';
import 'profile_metrics.dart';

/// Every animated value of the profile header for one given header height.
///
/// The header has exactly one input - its current extent - and this class
/// turns it into the position, size, radius and opacity of each part. Keeping
/// the maths here instead of scattered through the widget tree means the whole
/// animation can be reasoned about, unit tested and tuned in one place, and
/// that the widgets stay a thin declarative layer over it. Because nothing
/// depends on scroll direction, scrolling back up plays every stage in
/// reverse.
///
/// Two independent progress values drive everything:
///
///  * [galleryProgress] runs 0 -> 1 as the header grows from its resting
///    height to the full-bleed cover. The circle grows into a rounded square
///    and then widens into the photo filling the header.
///  * [dockProgress] runs 0 -> 1 as the header shrinks from resting to the
///    pinned app bar. Over its first half a black hole opens at the top of the
///    screen and swallows the rising, blurring avatar; over its second half
///    the action row collapses.
///
/// They are mutually exclusive: at most one is non-zero at any time.
@immutable
class HeaderGeometry {
  const HeaderGeometry._({
    required this.metrics,
    required this.extent,
    required this.galleryProgress,
    required this.dockProgress,
    required this.avatarRect,
    required this.avatarCornerRadius,
    required this.avatarOpacity,
    required this.avatarBlurSigma,
    required this.avatarInk,
    required this.swallowRect,
    required this.swallowContact,
    required this.identityTop,
    required this.identityScale,
    required this.identityLeft,
    required this.identityAlignX,
    required this.actionsTop,
    required this.actionsOpacity,
    required this.actionsScaleY,
    required this.coverScrimOpacity,
    required this.coverBlurOpacity,
    required this.storyIndicatorOpacity,
  });

  /// Share of [dockProgress] spent swallowing the avatar. The action row
  /// only starts collapsing once the avatar is gone.
  static const double swallowEnd = 0.5;

  /// Outer scroll offset at which the avatar is fully swallowed. The swallow
  /// runs from the resting offset ([ProfileMetrics.galleryRange]) to here.
  static double swallowOffset(ProfileMetrics metrics) =>
      metrics.galleryRange +
      math.max(0.0, metrics.restingExtent - metrics.collapsedExtent) *
          swallowEnd;

  factory HeaderGeometry.resolve({
    required ProfileMetrics metrics,
    required double extent,
  }) {
    final gallery = _galleryProgress(metrics, extent);

    // Past the fully open gallery the sliver keeps stretching on overscroll;
    // the extra height is handed to the photo so it grows with the pull
    // instead of leaving a gap under it.
    final overstretch = math.max(0.0, extent - metrics.expandedExtent);

    final restingCircle = Rect.fromLTWH(
      (metrics.screen.width - metrics.restingAvatarDiameter) / 2,
      metrics.restingAvatarTop,
      metrics.restingAvatarDiameter,
      metrics.restingAvatarDiameter,
    );

    Rect avatarRect = restingCircle;
    double avatarRadius = restingCircle.shortestSide / 2;
    double avatarOpacity = 1;
    double avatarBlur = 0;
    double avatarInk = 0;
    double swallowContact = 0;
    Rect swallowRect = Rect.fromCircle(
      center: metrics.swallowCenter,
      radius: 0,
    );
    double dock = 0;

    if (gallery > 0) {
      (avatarRect, avatarRadius) = _galleryAvatar(
        metrics: metrics,
        restingCircle: restingCircle,
        overstretch: overstretch,
        gallery: gallery,
      );
    } else {
      dock = _dockProgress(metrics, extent);
      final swallow = phase(dock, 0, swallowEnd);

      // A dot appears, then opens up and sinks towards the approaching
      // avatar; a neck grows between them, thin and photo-coloured at first,
      // then widening into the hole's black belly; finally the hole closes
      // over whatever is left.
      final appear = curvedPhase(swallow, 0, 0.25, Curves.easeOutCubic);
      final open = curvedPhase(swallow, 0.3, 0.65, Curves.easeInOutSine);
      swallowContact = curvedPhase(swallow, 0.45, 0.85, Curves.easeInOutSine);
      final close = curvedPhase(swallow, 0.85, 1, Curves.easeInCubic);

      final holeCenter =
          metrics.swallowCenter +
          Offset(0, ProfileMetrics.swallowHoleDrop * open);
      final double holeDiameter = lerp(
        ProfileMetrics.swallowDotDiameter,
        ProfileMetrics.swallowHoleDiameter,
        open,
      );
      swallowRect = Rect.fromCircle(
        center: holeCenter,
        radius: holeDiameter / 2 * appear * (1 - close),
      );

      final pulled = Rect.lerp(
        restingCircle,
        Rect.fromCircle(
          center:
              holeCenter + const Offset(0, ProfileMetrics.swallowedAvatarSink),
          radius: ProfileMetrics.swallowedAvatarDiameter / 2,
        ),
        Curves.easeInOutSine.transform(swallow),
      )!;
      // Whatever is left of the avatar shrinks with the closing hole so it
      // never pokes out of it.
      avatarRect = Rect.fromCircle(
        center: pulled.center,
        radius: pulled.shortestSide / 2 * (1 - close),
      );
      avatarRadius = avatarRect.shortestSide / 2;
      // Starts softening as soon as the avatar heads for the hole and is
      // fully blurred by the time the belly closes over it.
      avatarBlur =
          ProfileMetrics.swallowMaxBlur *
          curvedPhase(swallow, 0.1, 0.8, Curves.easeInOutSine);
      avatarInk =
          ProfileMetrics.swallowMaxInk *
          curvedPhase(swallow, 0.6, 1, Curves.easeIn);
      avatarOpacity = 1 - phase(swallow, 0.85, 1);
    }

    // --- Name and status --------------------------------------------------
    //
    // Going up, the block follows the scroll until it reaches the app bar
    // and then stays put, while it drifts from centred to the leading edge.
    final double identityTop;
    final double identityScale;
    final double identityLeft;
    final double identityAlignX;

    if (gallery > 0) {
      final eased = Curves.easeInOutCubic.transform(gallery);
      identityTop = lerp(
        metrics.restingIdentityTop,
        metrics.expandedIdentityTop + overstretch,
        eased,
      );
      identityScale = lerp(
        ProfileMetrics.restingNameScale,
        ProfileMetrics.expandedNameScale,
        eased,
      );
      identityLeft = ProfileMetrics.identityLeftExpanded;
      identityAlignX = lerp(0.5, 0, eased);
    } else {
      final travelled = metrics.restingExtent - extent;
      identityTop = (metrics.restingIdentityTop - travelled).clamp(
        metrics.dockedIdentityTop,
        metrics.restingIdentityTop,
      );
      final slide = curvedPhase(dock, 0.08, 0.7, Curves.easeInOutCubic);
      identityScale = lerp(
        ProfileMetrics.restingNameScale,
        ProfileMetrics.collapsedNameScale,
        dock,
      );
      identityLeft = lerp(
        ProfileMetrics.identityLeftExpanded,
        ProfileMetrics.identityLeftDocked,
        slide,
      );
      identityAlignX = lerp(0.5, 0, slide);
    }

    // --- Action buttons ---------------------------------------------------
    //
    // Anchored to the bottom edge of the header in every state. Once the
    // avatar is gone they shrink towards that edge and fade out.
    final actionsTop =
        extent -
        ProfileMetrics.headerBottomPadding -
        ProfileMetrics.actionsHeight;
    final collapse = curvedPhase(dock, swallowEnd, 0.95, Curves.easeInCubic);

    return HeaderGeometry._(
      metrics: metrics,
      extent: extent,
      galleryProgress: gallery,
      dockProgress: dock,
      avatarRect: avatarRect,
      avatarCornerRadius: avatarRadius,
      avatarOpacity: avatarOpacity,
      avatarBlurSigma: avatarBlur,
      avatarInk: avatarInk,
      swallowRect: swallowRect,
      swallowContact: swallowContact,
      identityTop: identityTop,
      identityScale: identityScale,
      identityLeft: identityLeft,
      identityAlignX: identityAlignX,
      actionsTop: actionsTop,
      actionsOpacity: 1 - phase(dock, swallowEnd, 0.92),
      actionsScaleY: 1 - collapse,
      coverScrimOpacity: phase(gallery, 0.3, 1),
      coverBlurOpacity: curvedPhase(gallery, 0.4, 1, Curves.easeInOutSine),
      storyIndicatorOpacity: phase(gallery, 0.45, 1),
    );
  }

  final ProfileMetrics metrics;

  /// Current height of the header sliver.
  final double extent;

  /// 0 at the resting state, 1 when the cover gallery is fully open.
  final double galleryProgress;

  /// 0 at the resting state, 1 when the header is a pinned app bar.
  final double dockProgress;

  final Rect avatarRect;
  final double avatarCornerRadius;

  /// 1 everywhere except the tail of the swallow, where it fades to 0.
  final double avatarOpacity;

  /// Blur applied to the photo as it is pulled into the black hole.
  final double avatarBlurSigma;

  /// 0 -> 1 while the black ink spreads down the photo from the hole's side.
  final double avatarInk;

  /// The black hole at the top of the screen. Empty when not swallowing.
  final Rect swallowRect;

  /// 0 -> 1 as the neck between hole and avatar turns from a thin,
  /// photo-coloured thread into the hole's wide black belly.
  final double swallowContact;

  final double identityTop;
  final double identityScale;
  final double identityLeft;

  /// 0.5 while the name is centred, 0 once it is left-aligned.
  final double identityAlignX;

  final double actionsTop;
  final double actionsOpacity;

  /// Vertical scale of the action row, anchored to its bottom edge.
  final double actionsScaleY;

  /// Darkening applied under the name while it sits on the photo.
  final double coverScrimOpacity;

  /// Opacity of the blurred band behind the name on the open cover.
  final double coverBlurOpacity;

  final double storyIndicatorOpacity;

  bool get isAvatarVisible => avatarOpacity > 0.01;

  /// Avatar rect and corner radius while the gallery opens.
  ///
  /// The rect follows a quadratic curve from the resting circle towards a
  /// rounded square under the status bar and on to the full-bleed cover, so
  /// it first grows as a square and only then widens to the screen edges,
  /// all along one smooth path with no stage boundary. The corners soften
  /// from a circle into a fixed "modern" radius and square off only as the
  /// photo fills the header.
  static (Rect, double) _galleryAvatar({
    required ProfileMetrics metrics,
    required Rect restingCircle,
    required double overstretch,
    required double gallery,
  }) {
    final coverRect = Rect.fromLTWH(
      0,
      0,
      metrics.screen.width,
      metrics.expandedExtent + overstretch,
    );
    final double side = math.min(
      metrics.screen.width * ProfileMetrics.galleryWaypointWidthFactor,
      coverRect.height,
    );
    final waypoint = Rect.fromLTWH(
      (metrics.screen.width - side) / 2,
      metrics.topInset,
      side,
      side,
    );

    final t = Curves.easeInOutSine.transform(gallery);
    final rect = Rect.lerp(
      Rect.lerp(restingCircle, waypoint, t)!,
      Rect.lerp(waypoint, coverRect, t)!,
      t,
    )!;

    final double circle = rect.shortestSide / 2;
    final soften = curvedPhase(gallery, 0.08, 0.5, Curves.easeInOutSine);
    final squareOff = curvedPhase(gallery, 0.7, 1, Curves.easeInOutSine);
    final double radius = math.min(
      circle,
      lerp(circle, ProfileMetrics.coverCornerRadius, soften),
    );
    return (rect, radius * (1 - squareOff));
  }

  static double _galleryProgress(ProfileMetrics metrics, double extent) {
    if (extent <= metrics.restingExtent) return 0;
    return phase(extent, metrics.restingExtent, metrics.expandedExtent);
  }

  static double _dockProgress(ProfileMetrics metrics, double extent) {
    final double span = metrics.restingExtent - metrics.collapsedExtent;
    if (span <= 0) return extent <= metrics.collapsedExtent ? 1 : 0;
    return ((metrics.restingExtent - extent) / span).clamp(0.0, 1.0);
  }
}
