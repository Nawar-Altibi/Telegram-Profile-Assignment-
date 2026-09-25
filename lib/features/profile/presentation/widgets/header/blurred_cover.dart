import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Width, in pixels, of the pre-blurred copy of the cover. The copy is only
/// ever seen through a heavy blur, so it is upscaled at no visible cost.
const int bakedCoverWidth = 96;

/// Renders a small, blurred copy of [source] once, off the scroll path.
///
/// [sigma] is in pixels of the baked image. The photo is drawn through a
/// clamped [ImageShader] into a padded canvas so its edge pixels extend
/// outwards; the blur then has real colour to sample at the borders instead
/// of fading into transparent black, and the padding is cropped away.
Future<ui.Image> bakeBlurredCover(
  ui.Image source, {
  required double sigma,
  int width = bakedCoverWidth,
}) async {
  final int height = math.max(
    1,
    (width * source.height / source.width).round(),
  );
  final int pad = (sigma * 3).ceil();
  final double scale = width / source.width;
  final Rect padded = Rect.fromLTWH(
    0,
    0,
    (width + pad * 2).toDouble(),
    (height + pad * 2).toDouble(),
  );

  final blurRecorder = ui.PictureRecorder();
  final blurCanvas = Canvas(blurRecorder, padded);
  final transform = Matrix4.diagonal3Values(scale, scale, 1)
    ..setTranslationRaw(pad.toDouble(), pad.toDouble(), 0);
  blurCanvas
    ..saveLayer(
      padded,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    )
    ..drawRect(
      padded,
      Paint()
        ..shader = ImageShader(
          source,
          TileMode.clamp,
          TileMode.clamp,
          transform.storage,
          filterQuality: FilterQuality.medium,
        ),
    )
    ..restore();
  final ui.Picture blurPicture = blurRecorder.endRecording();
  final ui.Image blurred = await blurPicture.toImage(
    padded.width.toInt(),
    padded.height.toInt(),
  );
  blurPicture.dispose();

  final cropRecorder = ui.PictureRecorder();
  final Rect target = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  Canvas(cropRecorder, target).drawImageRect(
    blurred,
    target.shift(Offset(pad.toDouble(), pad.toDouble())),
    target,
    Paint(),
  );
  final ui.Picture cropPicture = cropRecorder.endRecording();
  final ui.Image cropped = await cropPicture.toImage(width, height);
  cropPicture.dispose();
  blurred.dispose();
  return cropped;
}

/// Fades the pre-blurred cover in over the sharp one: fully transparent down
/// to [startFraction] of the height, then easing into [opacity] at the bottom
/// edge.
///
/// The fade-in opacity is folded into the mask's alpha, so the whole effect
/// is a single [ShaderMask] layer with no extra [Opacity] layer.
class CoverBlurMask extends StatelessWidget {
  const CoverBlurMask({
    super.key,
    required this.opacity,
    required this.startFraction,
    required this.child,
  });

  final double opacity;

  /// Where the blur begins, as a fraction of the photo's height.
  final double startFraction;

  /// The baked, blurred photo; built once by the header and reused.
  final Widget child;

  /// Gradient stops used to approximate the ease below.
  static const int _steps = 8;
  static const Curve _fade = Curves.easeInOutSine;

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= _steps; i++) {
      final double t = i / _steps;
      stops.add(startFraction + (1 - startFraction) * t);
      colors.add(Color.fromRGBO(0, 0, 0, opacity * _fade.transform(t)));
    }
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    );
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: gradient.createShader,
      child: child,
    );
  }
}
