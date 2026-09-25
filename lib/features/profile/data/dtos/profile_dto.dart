/// Raw shape of the profile owner as it arrives from a data source.
class ProfileDto {
  const ProfileDto({
    required this.displayName,
    required this.username,
    required this.phoneNumber,
    required this.bio,
    required this.birthday,
    required this.avatarAssetPath,
    required this.isOnline,
    required this.storyCount,
    required this.unreadChatCount,
  });

  final String displayName;
  final String username;
  final String phoneNumber;
  final String bio;
  final DateTime birthday;
  final String avatarAssetPath;
  final bool isOnline;
  final int storyCount;
  final int unreadChatCount;
}
