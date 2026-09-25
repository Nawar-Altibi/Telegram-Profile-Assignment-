import 'package:flutter/foundation.dart';

import '../../data/repositories/profile_repository.dart';
import '../../enums/profile_tab.dart';
import '../view_models/media_item_view_model.dart';
import '../view_models/profile_view_model.dart';

/// Holds the screen's state: the profile, the selected tab and its media.
///
/// A plain [ChangeNotifier] is enough here - the screen has one owner and no
/// cross-feature state - so the project stays free of state-management
/// dependencies. Note that scroll position is deliberately *not* kept here:
/// the header reads its progress straight from the sliver protocol, so
/// scrolling never goes through this notifier and never rebuilds the screen.
///
/// The notifier itself fires only when the data changes. The selected tab
/// has its own [tabListenable]: the tab strip and the pages already follow
/// the screen's `TabController`, so a tab switch must not rebuild the shell
/// and every grid under it.
class ProfileController extends ChangeNotifier {
  ProfileController({ProfileRepository repository = const ProfileRepository()})
    : _repository = repository;

  final ProfileRepository _repository;

  ProfileViewModel? _profile;
  ProfileViewModel? get profile => _profile;

  final ValueNotifier<ProfileTab> _tab = ValueNotifier<ProfileTab>(
    ProfileTab.posts,
  );
  ValueListenable<ProfileTab> get tabListenable => _tab;
  ProfileTab get tab => _tab.value;

  final Map<ProfileTab, List<MediaItemViewModel>> _mediaByTab =
      <ProfileTab, List<MediaItemViewModel>>{};

  List<MediaItemViewModel> mediaFor(ProfileTab tab) =>
      _mediaByTab[tab] ?? const <MediaItemViewModel>[];

  /// Media of the selected tab.
  List<MediaItemViewModel> get media => mediaFor(tab);

  /// Loads synchronously so the first frame is already complete.
  void load() {
    _profile = _repository.loadProfile();
    for (final tab in ProfileTab.values) {
      _mediaByTab[tab] = _repository.loadMedia(tab);
    }
    notifyListeners();
  }

  void selectTab(ProfileTab tab) {
    _tab.value = tab;
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }
}
