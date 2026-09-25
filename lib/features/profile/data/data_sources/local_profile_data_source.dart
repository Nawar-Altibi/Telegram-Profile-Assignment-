import '../../enums/media_kind.dart';
import '../../enums/profile_tab.dart';
import '../dtos/media_item_dto.dart';
import '../dtos/profile_dto.dart';

/// In-memory stand-in for a backend.
///
/// The assignment asks for mock data, so the whole app is fed from here. Every
/// grid tile is produced from this list; nothing in the UI hardcodes a post.
class LocalProfileDataSource {
  const LocalProfileDataSource();

  /// Flip either list to `const []` to exercise the empty states described in
  /// the README.
  ProfileDto readProfile() => ProfileDto(
    displayName: 'Nawar',
    username: '@NawarAlTibi',
    phoneNumber: '+963 95-7456941',
    bio:
        '{فَنَادَىٰ فِي الظُّلُمَاتِ أَن لَّا إِلَٰهَ إِلَّا أَنتَ '
        'سُبْحَانَكَ إِنِّي كُنتُ مِنَ الظَّالِمِينَ}',
    birthday: DateTime(2004, 4, 1),
    avatarAssetPath: avatarAssetPath,
    isOnline: true,
    storyCount: 4,
    unreadChatCount: 162,
  );

  static const String avatarAssetPath = 'assets/images/avatar.jpg';

  List<MediaItemDto> readMedia(ProfileTab tab) => switch (tab) {
    ProfileTab.posts => _posts,
    ProfileTab.archived => _archived,
  };

  static const List<MediaItemDto> _posts = <MediaItemDto>[
    MediaItemDto(
      id: 'p01',
      assetPath: 'assets/images/post_1.jpg',
      kind: MediaKind.photo,
      viewCount: 1284,
    ),
    MediaItemDto(
      id: 'p02',
      assetPath: 'assets/images/post_2.jpg',
      kind: MediaKind.video,
      viewCount: 948,
    ),
    MediaItemDto(
      id: 'p03',
      assetPath: 'assets/images/post_3.jpg',
      kind: MediaKind.photo,
      viewCount: 612,
    ),
    MediaItemDto(
      id: 'p04',
      assetPath: 'assets/images/post_4.jpg',
      kind: MediaKind.photo,
      viewCount: 437,
    ),
  ];

  static const List<MediaItemDto> _archived = <MediaItemDto>[
    MediaItemDto(
      id: 'a01',
      assetPath: 'assets/images/post_5.jpg',
      kind: MediaKind.photo,
      viewCount: 94,
    ),
  ];
}
