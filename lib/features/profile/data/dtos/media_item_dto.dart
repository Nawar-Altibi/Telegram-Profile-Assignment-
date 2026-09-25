import '../../enums/media_kind.dart';

/// Raw shape of one media post as it arrives from a data source.
class MediaItemDto {
  const MediaItemDto({
    required this.id,
    required this.assetPath,
    required this.kind,
    required this.viewCount,
    this.durationSeconds,
    this.isPinned = false,
  });

  final String id;
  final String assetPath;
  final MediaKind kind;
  final int viewCount;
  final int? durationSeconds;
  final bool isPinned;
}
