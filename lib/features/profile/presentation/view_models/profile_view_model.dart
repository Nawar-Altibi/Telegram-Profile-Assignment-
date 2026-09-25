import 'dart:ui' show TextDirection;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart' show AssetImage, ImageProvider;

/// One row of the information card, already formatted and direction-resolved.
@immutable
class ProfileFieldViewModel {
  const ProfileFieldViewModel({
    required this.value,
    required this.label,
    required this.valueDirection,
    this.isCopyable = true,
  });

  final String value;
  final String label;

  /// Resolved per field so the Arabic bio aligns right while the Latin rows
  /// stay left, matching the reference.
  final TextDirection valueDirection;

  /// Whether a long press copies [value] to the clipboard.
  final bool isCopyable;
}

/// Everything the profile screen needs about the account owner.
@immutable
class ProfileViewModel {
  const ProfileViewModel({
    required this.displayName,
    required this.statusText,
    required this.storyCountText,
    required this.storyCount,
    required this.avatarAssetPath,
    required this.fields,
    required this.unreadChatCount,
  });

  final String displayName;

  /// `online` / `last seen recently`.
  final String statusText;

  /// `4 stories`; the collapsed app bar alternates between this and
  /// [statusText] exactly like the reference does.
  final String storyCountText;

  /// Number of story frames. Drives the segment bar on the open cover.
  final int storyCount;

  final String avatarAssetPath;
  final List<ProfileFieldViewModel> fields;
  final int unreadChatCount;

  ImageProvider get avatar => AssetImage(avatarAssetPath);
}
