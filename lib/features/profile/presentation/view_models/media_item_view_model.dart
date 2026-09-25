import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart' show AssetImage, ImageProvider;

import '../../enums/media_kind.dart';

/// One grid tile, with its badges already formatted.
@immutable
class MediaItemViewModel {
  const MediaItemViewModel({
    required this.id,
    required this.assetPath,
    required this.kind,
    required this.viewCountLabel,
    required this.isPinned,
    this.durationLabel,
  });

  final String id;
  final String assetPath;
  final MediaKind kind;
  final String viewCountLabel;
  final String? durationLabel;
  final bool isPinned;

  ImageProvider get thumbnail => AssetImage(assetPath);
}
