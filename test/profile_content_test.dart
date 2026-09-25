import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_profile/core/utils/count_formatter.dart';
import 'package:telegram_profile/core/utils/date_formatter.dart';
import 'package:telegram_profile/core/utils/text_direction_resolver.dart';
import 'package:telegram_profile/features/profile/data/data_sources/local_profile_data_source.dart';
import 'package:telegram_profile/features/profile/data/dtos/media_item_dto.dart';
import 'package:telegram_profile/features/profile/data/repositories/profile_repository.dart';
import 'package:telegram_profile/features/profile/enums/profile_tab.dart';
import 'package:telegram_profile/features/profile/presentation/controller/profile_controller.dart';
import 'package:telegram_profile/features/profile/presentation/layout/profile_metrics.dart';
import 'package:telegram_profile/features/profile/presentation/screens/profile_screen.dart';
import 'package:telegram_profile/features/profile/presentation/view_models/media_item_view_model.dart';
import 'package:telegram_profile/features/profile/presentation/widgets/empty/empty_media_view.dart';
import 'package:telegram_profile/features/profile/presentation/widgets/grid/media_tile.dart';

/// A data source with nothing in it, for the empty states.
class _EmptyDataSource extends LocalProfileDataSource {
  const _EmptyDataSource();

  @override
  List<MediaItemDto> readMedia(ProfileTab tab) => const <MediaItemDto>[];
}

void main() {
  group('formatters', () {
    test('compacts view counts the way the reference badges do', () {
      expect(formatCompactCount(0), '0');
      expect(formatCompactCount(58), '58');
      expect(formatCompactCount(999), '999');
      expect(formatCompactCount(1284), '1.3K');
      expect(formatCompactCount(8210), '8.2K');
      expect(formatCompactCount(12400), '12.4K');
      expect(formatCompactCount(1200000), '1.2M');
    });

    test('formats clip durations', () {
      expect(formatMediaDuration(const Duration(seconds: 5)), '0:05');
      expect(formatMediaDuration(const Duration(seconds: 74)), '1:14');
      expect(formatMediaDuration(const Duration(minutes: 63)), '1:03:00');
    });

    test('reports the age as of the given day, not the build date', () {
      final birthday = DateTime(2004, 4, 1);
      expect(
        formatBirthdayWithAge(birthday, now: DateTime(2026, 9, 24)),
        'Apr 01, 2004 (22 years old)',
      );
      // The day before the birthday the person is still a year younger.
      expect(
        formatBirthdayWithAge(birthday, now: DateTime(2026, 3, 31)),
        'Apr 01, 2004 (21 years old)',
      );
      expect(
        formatBirthdayWithAge(birthday, now: DateTime(2026, 4, 1)),
        'Apr 01, 2004 (22 years old)',
      );
    });

    test('resolves direction from the first strong character', () {
      expect(resolveTextDirection('@NawarAlTibi'), TextDirection.ltr);
      expect(resolveTextDirection('+963 95-7456941'), TextDirection.ltr);
      expect(
        resolveTextDirection('{فَنَادَىٰ فِي الظُّلُمَاتِ}'),
        TextDirection.rtl,
      );
      // Leading punctuation and digits are not strong, so they do not decide.
      expect(resolveTextDirection('... hello'), TextDirection.ltr);
      expect(resolveTextDirection('123 مرحبا'), TextDirection.rtl);
      expect(resolveTextDirection('   '), TextDirection.ltr);
    });
  });

  group('ProfileRepository', () {
    const repository = ProfileRepository();

    test('builds the four information rows with per-field direction', () {
      final profile = repository.loadProfile();
      expect(profile.fields.map((f) => f.label), <String>[
        'Mobile',
        'Bio',
        'Username',
        'Birthday',
      ]);
      final bio = profile.fields[1];
      expect(bio.valueDirection, TextDirection.rtl);
      expect(profile.fields.first.valueDirection, TextDirection.ltr);
      expect(profile.storyCountText, '4 stories');
      expect(profile.statusText, 'online');
    });

    test('gives every tab its own media, formatted for display', () {
      final posts = repository.loadMedia(ProfileTab.posts);
      final archived = repository.loadMedia(ProfileTab.archived);

      expect(posts, hasLength(4));
      expect(archived, hasLength(1));
      expect(posts.map((m) => m.thumbnail).toSet(), hasLength(posts.length));
      expect(
        posts
            .map((m) => m.id)
            .toSet()
            .intersection(archived.map((m) => m.id).toSet()),
        isEmpty,
      );
      expect(posts.first.viewCountLabel, '1.3K');
      expect(posts.any((m) => m.isPinned), isFalse);
      expect(posts.every((m) => m.durationLabel == null), isTrue);
    });

    test('lets every field but the birthday be copied', () {
      final fields = repository.loadProfile().fields;
      expect(fields.where((f) => f.isCopyable).map((f) => f.label), <String>[
        'Mobile',
        'Bio',
        'Username',
      ]);
    });
  });

  group('ProfileController', () {
    test('swaps the media list when the tab changes', () {
      final controller = ProfileController()..load();
      addTearDown(controller.dispose);

      final posts = controller.media;
      expect(controller.tab, ProfileTab.posts);

      var tabNotifications = 0;
      var dataNotifications = 0;
      controller.tabListenable.addListener(() => tabNotifications++);
      controller.addListener(() => dataNotifications++);

      controller.selectTab(ProfileTab.archived);
      expect(controller.tab, ProfileTab.archived);
      expect(controller.media, isNot(posts));
      expect(tabNotifications, 1);

      // Re-selecting the current tab is a no-op rather than a rebuild.
      controller.selectTab(ProfileTab.archived);
      expect(tabNotifications, 1);

      // A tab switch must not reach whoever listens for data (the shell).
      expect(dataNotifications, 0);
    });
  });

  group('ProfileScreen states', () {
    Future<void> pump(
      WidgetTester tester, {
      required ProfileTab tab,
      required List<MediaItemViewModel> media,
      ValueChanged<ProfileTab>? onTabChanged,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              profile: const ProfileRepository().loadProfile(),
              mediaByTab: {tab: media},
              tab: tab,
              onTabChanged: onTabChanged ?? (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('lists the posts tab lazily', (tester) async {
      final media = const ProfileRepository().loadMedia(ProfileTab.posts);
      await pump(tester, tab: ProfileTab.posts, media: media);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyMediaView), findsNothing);
      // Lazy: never more tiles than there are items.
      final built = tester.widgetList<MediaTile>(find.byType(MediaTile)).length;
      expect(built, greaterThan(0));
      expect(built, lessThanOrEqualTo(media.length));
    });

    testWidgets('explains the archived tab above its grid', (tester) async {
      await pump(
        tester,
        tab: ProfileTab.archived,
        media: const ProfileRepository().loadMedia(ProfileTab.archived),
      );

      await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.byType(ArchivedNotice), findsOneWidget);
    });

    testWidgets('shows the empty state when a tab has no media', (
      tester,
    ) async {
      const repository = ProfileRepository(dataSource: _EmptyDataSource());
      expect(repository.loadMedia(ProfileTab.posts), isEmpty);

      await pump(
        tester,
        tab: ProfileTab.posts,
        media: repository.loadMedia(ProfileTab.posts),
      );
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.byType(MediaTile), findsNothing);
      expect(find.text('No posts yet...'), findsOneWidget);
    });

    testWidgets('the last row scrolls clear of the floating controls', (
      tester,
    ) async {
      final posts = const ProfileRepository().loadMedia(ProfileTab.posts);
      final media = <MediaItemViewModel>[
        for (var i = 0; i < 40; i++)
          MediaItemViewModel(
            id: 'many-$i',
            assetPath: posts[i % posts.length].assetPath,
            kind: posts[i % posts.length].kind,
            viewCountLabel: '1',
            isPinned: false,
          ),
      ];
      await pump(tester, tab: ProfileTab.posts, media: media);
      for (var i = 0; i < 6; i++) {
        await tester.drag(
          find.byType(NestedScrollView),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
      }

      final metrics = ProfileMetrics.of(
        tester.element(find.byType(ProfileScreen)),
      );
      final lastTile = tester.getRect(
        find.byKey(ValueKey<String>(media.last.id)),
      );
      expect(
        lastTile.bottom,
        lessThanOrEqualTo(
          metrics.screen.height - metrics.floatingControlsClearance + 0.5,
        ),
      );
    });

    testWidgets('tapping a tab reports the new selection', (tester) async {
      ProfileTab? requested;
      await pump(
        tester,
        tab: ProfileTab.posts,
        media: const ProfileRepository().loadMedia(ProfileTab.posts),
        onTabChanged: (tab) => requested = tab,
      );
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Archived Posts'));
      await tester.pump();

      expect(requested, ProfileTab.archived);
    });
  });
}
