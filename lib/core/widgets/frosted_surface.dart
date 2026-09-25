import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Rounded translucent surface with a backdrop blur behind it.
///
/// The filter has to be outside any [RepaintBoundary]. A boundary above the
/// filter isolates an empty layer, so the blur never sees the scrolling grid
/// and the tint reads as a solid bar.
///
/// The filter joins the nearest [BackdropGroup], so sibling surfaces share
/// one backdrop capture. Surfaces in the same group must not overlap each
/// other, and nothing they should see through may paint between them.
///
/// Never wrap this in an [Opacity]: the opacity layer would hide the real
/// backdrop from the filter. Fade it with [opacity] instead, which scales the
/// tint, the border and the blur, and fold the same value into the child's
/// colours.
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.blurSigma = 18,
    this.tint = const Color(0x991B242D),
    this.borderColor,
    this.borderWidth = 1,
    this.blur = true,
    this.opacity = 1,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color tint;
  final Color? borderColor;
  final double borderWidth;

  /// False draws only the tint. Use it when whatever sits behind the surface
  /// is flat enough that blurring it would change nothing on screen.
  final bool blur;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final double o = opacity.clamp(0.0, 1.0);
    final Color? border = borderColor;
    final Widget surface = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tint.withValues(alpha: tint.a * o),
          borderRadius: borderRadius,
          border: border == null
              ? null
              : Border.all(
                  color: border.withValues(alpha: border.a * o),
                  width: borderWidth,
                ),
        ),
        child: child,
      ),
    );

    final double sigma = blurSigma * o;
    if (!blur || sigma <= 0) {
      return ClipRRect(borderRadius: borderRadius, child: surface);
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: surface,
      ),
    );
  }
}
