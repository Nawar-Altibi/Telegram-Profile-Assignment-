import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'profile_metrics.dart';

/// The one decode size used for post images.
///
/// The grid, the story / post preview and the precache all ask for exactly
/// this provider, so each asset is decoded once, at the size of the larger of
/// its two on-screen uses, and every later request is an [ImageCache] hit.
/// A different width anywhere would be a different cache key and a second,
/// full decode.
abstract final class MediaImages {
  /// Width of the floating preview card.
  static double previewCardWidth(Size screen) =>
      (screen.width * 0.66).clamp(200.0, 360.0);

  static double tileWidth(ProfileMetrics metrics) {
    final int columns = metrics.gridColumnCount;
    return (metrics.screen.width -
            ProfileMetrics.gridMargin * 2 -
            ProfileMetrics.gridSpacing * (columns - 1)) /
        columns;
  }

  /// Physical pixel width every post image is decoded at.
  static int decodeWidth(ProfileMetrics metrics, double devicePixelRatio) {
    final double logical = math.max(
      tileWidth(metrics),
      previewCardWidth(metrics.screen),
    );
    return math.max(1, (logical * devicePixelRatio).round());
  }

  static ImageProvider provider(String assetPath, int decodeWidth) {
    return ResizeImage(
      AssetImage(assetPath),
      width: decodeWidth,
      policy: ResizeImagePolicy.fit,
    );
  }
}
