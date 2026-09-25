import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The avatar being swallowed by the black hole at the top of the screen.
///
/// Hole, neck and avatar are one metaball shape. Once the avatar is within
/// reach a thin neck grows between them, filled with the photo's own colours
/// smeared up from its top edge. As [contact] rises the neck widens into the
/// hole's black belly and the black spreads down over the photo, which blurs,
/// shrinks and finally fades inside it.
///
/// Everything is drawn by one [CustomPainter] with no widget layers: the
/// photo is filled through an [ImageShader] inside a single clip to the body
/// outline, and its blur and opacity share one offscreen layer bounded to the
/// avatar, so the blur costs a few thousand pixels rather than the header.
class SwallowedAvatar extends StatelessWidget {
  const SwallowedAvatar({
    super.key,
    required this.hole,
    required this.avatar,
    required this.image,
    required this.contact,
    required this.ink,
    required this.blurSigma,
    required this.opacity,
  });

  /// Circle of the hole, in the same coordinates as [avatar].
  final Rect hole;

  /// Circle the avatar occupies; empty once it has been swallowed.
  final Rect avatar;

  /// The decoded photo; only the black body is drawn until it is available.
  final ui.Image? image;

  /// 0 (thin, photo-coloured thread) to 1 (wide black belly).
  final double contact;

  /// 0 (none) to 1 (upper half black) of black spreading down the photo.
  final double ink;

  final double blurSigma;

  /// Opacity of the photo; the black body stays until the hole closes.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (hole.isEmpty && avatar.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        willChange: true,
        painter: _SwallowPainter(
          hole: hole,
          avatar: avatar,
          image: image,
          contact: contact,
          ink: ink,
          blurSigma: blurSigma,
          opacity: opacity,
        ),
      ),
    );
  }
}

/// Paints the hole, the neck and the avatar as one outline, then fills the
/// avatar part with the photo. Repaints only when an input changes.
class _SwallowPainter extends CustomPainter {
  _SwallowPainter({
    required this.hole,
    required this.avatar,
    required this.image,
    required this.contact,
    required this.ink,
    required this.blurSigma,
    required this.opacity,
  });

  final Rect hole;
  final Rect avatar;
  final ui.Image? image;
  final double contact;
  final double ink;
  final double blurSigma;
  final double opacity;

  /// How far, relative to the avatar radius, the neck can reach across the
  /// gap between the two circles.
  static const double _reach = 1.5;

  /// Neck width, 0 (a thread) to 1 (tangent to both circles), before and
  /// after contact.
  static const double _threadSpread = 0.2;
  static const double _bellySpread = 0.9;

  /// Opacity of the black over the neck before and after contact.
  static const double _threadInk = 0.3;

  /// Share of the photo, from its top edge, smeared up into the neck.
  static const double _smearSlice = 0.25;

  /// Length of the bezier handles relative to the radii.
  static const double _handleSize = 2.4;

  @override
  void paint(Canvas canvas, Size size) {
    final Path body = _body();
    canvas.drawPath(body, Paint()..color = Colors.black);

    if (avatar.isEmpty) return;

    // Everything below stays inside the crisp outline; the blurred photo
    // softens into the black body rather than past it.
    canvas
      ..save()
      ..clipPath(body);
    final ui.Image? photo = image;
    if (photo != null && opacity > 0) _paintPhoto(canvas, photo);
    _paintInk(canvas);
    canvas.restore();
  }

  /// The smeared neck and the round photo, filled through shaders. Blur and
  /// opacity are applied once to both, on a layer bounded to the avatar.
  void _paintPhoto(Canvas canvas, ui.Image photo) {
    final double pivot = avatar.top + avatar.height * _smearSlice;
    final double stretch = math.max(
      1,
      (pivot - hole.bottom) / (avatar.height * _smearSlice),
    );
    final band = Rect.fromLTRB(
      avatar.left,
      math.min(hole.bottom, avatar.center.dy),
      avatar.right,
      avatar.center.dy,
    );

    final bool blurred = blurSigma > 0.05;
    final bool layered = blurred || opacity < 1;
    if (layered) {
      final Paint layer = Paint()..color = Color.fromRGBO(0, 0, 0, opacity);
      if (blurred) {
        layer.imageFilter = ui.ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        );
      }
      final Rect bounds =
          (band.height > 0 ? avatar.expandToInclude(band) : avatar).inflate(
            blurSigma * 3,
          );
      canvas.saveLayer(bounds, layer);
    }

    if (band.height > 0) {
      canvas.drawRect(
        band,
        Paint()..shader = _photoShader(photo, stretchY: stretch, pivotY: pivot),
      );
    }
    canvas.drawOval(avatar, Paint()..shader = _photoShader(photo));

    if (layered) canvas.restore();
  }

  /// [photo] mapped onto [avatar] with [BoxFit.cover], optionally stretched
  /// vertically around [pivotY].
  ImageShader _photoShader(
    ui.Image photo, {
    double stretchY = 1,
    double pivotY = 0,
  }) {
    final double w = photo.width.toDouble();
    final double h = photo.height.toDouble();
    final double scale = math.max(avatar.width / w, avatar.height / h);
    final double dx = avatar.center.dx - w * scale / 2;
    final double dy = avatar.center.dy - h * scale / 2;
    final matrix = Float64List(16)
      ..[0] = scale
      ..[5] = scale * stretchY
      ..[10] = 1
      ..[12] = dx
      ..[13] = pivotY + stretchY * (dy - pivotY)
      ..[15] = 1;
    return ImageShader(
      photo,
      TileMode.clamp,
      TileMode.clamp,
      matrix,
      filterQuality: FilterQuality.medium,
    );
  }

  /// Black running from the hole down the neck and over the photo: faint on
  /// the thread, solid in the belly, and creeping further down with [ink].
  void _paintInk(Canvas canvas) {
    final double top = math.min(hole.center.dy, avatar.top);
    final area = Rect.fromLTRB(avatar.left, top, avatar.right, avatar.bottom);
    if (area.height <= 0) return;

    final double creep = avatar.height / 2 * ink;
    final double solidUntil = ui.lerpDouble(top, avatar.top, contact)! + creep;
    final double fadeUntil =
        ui.lerpDouble(avatar.top, avatar.center.dy, contact)! + creep;
    double at(double y) => ((y - top) / area.height).clamp(0.0, 1.0);

    final double alpha = ui.lerpDouble(_threadInk, 1, contact)!;
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Colors.black.withValues(alpha: alpha),
        Colors.black.withValues(alpha: 0),
      ],
      stops: <double>[at(solidUntil), math.max(at(solidUntil), at(fadeUntil))],
    ).createShader(area);

    canvas.drawRect(area, Paint()..shader = shader);
  }

  /// Hole, neck and avatar as one path.
  ///
  /// All three contours run clockwise, so under the non-zero fill rule their
  /// overlaps are filled once, exactly like a boolean union, without paying
  /// for `Path.combine` on every frame.
  Path _body() {
    final path = Path();
    if (!hole.isEmpty) _addCircle(path, hole);
    if (avatar.isEmpty) return path;
    _addCircle(path, avatar);
    if (!hole.isEmpty) {
      _addNeck(
        path,
        hole.center,
        hole.width / 2,
        avatar.center,
        avatar.shortestSide / 2,
        ui.lerpDouble(_threadSpread, _bellySpread, contact)!,
      );
    }
    return path;
  }

  static void _addCircle(Path path, Rect rect) {
    path
      ..arcTo(rect, 0, math.pi, true)
      ..arcTo(rect, math.pi, math.pi, false)
      ..close();
  }

  /// The bridge between two circles, closed with straight chords that lie
  /// inside them.
  static void _addNeck(
    Path path,
    Offset c1,
    double r1,
    Offset c2,
    double r2,
    double spread,
  ) {
    final d = (c2 - c1).distance;
    if (r1 <= 0 || r2 <= 0) return;
    if (d > r1 + r2 * _reach || d <= (r1 - r2).abs()) return;

    double u1 = 0;
    double u2 = 0;
    if (d < r1 + r2) {
      u1 = math.acos(_unit((r1 * r1 + d * d - r2 * r2) / (2 * r1 * d)));
      u2 = math.acos(_unit((r2 * r2 + d * d - r1 * r1) / (2 * r2 * d)));
    }

    final between = math.atan2(c2.dy - c1.dy, c2.dx - c1.dx);
    final maxSpread = math.acos(_unit((r1 - r2) / d));

    final a1 = between + u1 + (maxSpread - u1) * spread;
    final a2 = between - u1 - (maxSpread - u1) * spread;
    final a3 = between + math.pi - u2 - (math.pi - u2 - maxSpread) * spread;
    final a4 = between - math.pi + u2 + (math.pi - u2 - maxSpread) * spread;

    final p1 = _point(c1, a1, r1);
    final p2 = _point(c1, a2, r1);
    final p3 = _point(c2, a3, r2);
    final p4 = _point(c2, a4, r2);

    final handle =
        math.min(spread * _handleSize, (p1 - p3).distance / (r1 + r2)) *
        math.min(1.0, d * 2 / (r1 + r2));
    final h1 = _point(p1, a1 - math.pi / 2, r1 * handle);
    final h2 = _point(p2, a2 + math.pi / 2, r1 * handle);
    final h3 = _point(p3, a3 + math.pi / 2, r2 * handle);
    final h4 = _point(p4, a4 - math.pi / 2, r2 * handle);

    // Shoelace sign of p1 -> p3 -> p4 -> p2; positive is clockwise on a
    // y-down canvas, matching the circles.
    final double winding =
        (p1.dx * p3.dy - p3.dx * p1.dy) +
        (p3.dx * p4.dy - p4.dx * p3.dy) +
        (p4.dx * p2.dy - p2.dx * p4.dy) +
        (p2.dx * p1.dy - p1.dx * p2.dy);
    if (winding >= 0) {
      path
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(h1.dx, h1.dy, h3.dx, h3.dy, p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..cubicTo(h4.dx, h4.dy, h2.dx, h2.dy, p2.dx, p2.dy)
        ..close();
    } else {
      path
        ..moveTo(p2.dx, p2.dy)
        ..cubicTo(h2.dx, h2.dy, h4.dx, h4.dy, p4.dx, p4.dy)
        ..lineTo(p3.dx, p3.dy)
        ..cubicTo(h3.dx, h3.dy, h1.dx, h1.dy, p1.dx, p1.dy)
        ..close();
    }
  }

  /// Guards `acos` against rounding just outside [-1, 1].
  static double _unit(double value) => value.clamp(-1.0, 1.0);

  static Offset _point(Offset origin, double angle, double radius) =>
      origin + Offset(math.cos(angle), math.sin(angle)) * radius;

  @override
  bool shouldRepaint(_SwallowPainter old) =>
      old.hole != hole ||
      old.avatar != avatar ||
      old.image != image ||
      old.contact != contact ||
      old.ink != ink ||
      old.blurSigma != blurSigma ||
      old.opacity != opacity;
}
