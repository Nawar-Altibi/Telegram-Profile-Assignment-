import 'dart:ui' show TextDirection;

import '../../../../core/utils/count_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/text_direction_resolver.dart';
import '../../enums/profile_tab.dart';
import '../../presentation/view_models/media_item_view_model.dart';
import '../../presentation/view_models/profile_view_model.dart';
import '../data_sources/local_profile_data_source.dart';
import '../dtos/profile_dto.dart';

/// Turns data-source DTOs into presentation-ready view models.
///
/// All formatting - compact view counts, clip durations, the birthday age,
/// per-field text direction - happens here so widgets stay declarative.
class ProfileRepository {
  const ProfileRepository({
    LocalProfileDataSource dataSource = const LocalProfileDataSource(),
  }) : _dataSource = dataSource;

  final LocalProfileDataSource _dataSource;

  ProfileViewModel loadProfile() {
    final dto = _dataSource.readProfile();
    return ProfileViewModel(
      displayName: dto.displayName,
      statusText: dto.isOnline ? 'online' : 'last seen recently',
      storyCountText: _pluralStories(dto.storyCount),
      storyCount: dto.storyCount,
      avatarAssetPath: dto.avatarAssetPath,
      unreadChatCount: dto.unreadChatCount,
      fields: _buildFields(dto),
    );
  }

  List<MediaItemViewModel> loadMedia(ProfileTab tab) {
    return _dataSource
        .readMedia(tab)
        .map(
          (dto) => MediaItemViewModel(
            id: dto.id,
            assetPath: dto.assetPath,
            kind: dto.kind,
            isPinned: dto.isPinned,
            viewCountLabel: formatCompactCount(dto.viewCount),
            durationLabel: dto.durationSeconds == null
                ? null
                : formatMediaDuration(Duration(seconds: dto.durationSeconds!)),
          ),
        )
        .toList(growable: false);
  }

  static List<ProfileFieldViewModel> _buildFields(ProfileDto dto) {
    return <ProfileFieldViewModel>[
      ProfileFieldViewModel(
        value: dto.phoneNumber,
        label: 'Mobile',
        valueDirection: TextDirection.ltr,
      ),
      ProfileFieldViewModel(
        value: dto.bio,
        label: 'Bio',
        valueDirection: resolveTextDirection(dto.bio),
      ),
      ProfileFieldViewModel(
        value: dto.username,
        label: 'Username',
        valueDirection: TextDirection.ltr,
      ),
      ProfileFieldViewModel(
        value: formatBirthdayWithAge(dto.birthday),
        label: 'Birthday',
        valueDirection: TextDirection.ltr,
        isCopyable: false,
      ),
    ];
  }

  static String _pluralStories(int count) =>
      count == 1 ? '1 story' : '$count stories';
}
