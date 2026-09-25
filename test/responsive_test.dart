import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_profile/app/app.dart';
import 'package:telegram_profile/features/profile/data/repositories/profile_repository.dart';
import 'package:telegram_profile/features/profile/enums/profile_tab.dart';
import 'package:telegram_profile/features/profile/presentation/screens/profile_screen.dart';
import 'package:telegram_profile/features/profile/presentation/view_models/profile_view_model.dart';

/// Device profiles the app is expected to survive, in logical pixels.
const Map<String, Size> _viewports = <String, Size>{
  'Small Phone': Size(360, 640),
  'Pixel 8 Pro': Size(384, 854),
  'Pixel 9 Pro XL': Size(440, 956),
  'tablet': Size(834, 1112),
  'landscape phone': Size(854, 384),
  'landscape tablet': Size(1112, 834),
};

/// Any overflow, assertion or layout error inside the pump turns into a test
/// failure on its own, so these cases are assertions by construction. The
/// explicit expectations below just make the intent readable.
void main() {
  for (final entry in _viewports.entries) {
    testWidgets('lays out on ${entry.key}', (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = entry.value * 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const TelegramProfileApp());
      await tester.pump();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Nawar'), findsWidgets);

      // Scroll the whole way down and back to shake out anything that only
      // breaks once the header has docked.
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();
    });
  }

  for (final scale in <double>[0.85, 1.3, 1.6]) {
    testWidgets('survives a ${scale}x text scale', (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(360, 640) * 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const TelegramProfileApp(),
        ),
      );
      await tester.pump();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -1200));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('mirrors cleanly when the app itself is right to left', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(384, 854) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: TelegramProfileApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Posts'), findsOneWidget);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();
  });

  testWidgets('clips rather than overflows on absurd content', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(320, 568) * 3;
    addTearDown(tester.view.reset);

    final base = const ProfileRepository().loadProfile();
    final profile = ProfileViewModel(
      displayName: 'Nawar Al Tibi Al Halabi Al Shami Abu Muhammad Ibn Abdullah',
      statusText: 'last seen a very long time ago in a galaxy far away',
      storyCountText: '128 stories',
      storyCount: 128,
      avatarAssetPath: base.avatarAssetPath,
      unreadChatCount: 999999,
      fields: <ProfileFieldViewModel>[
        ...base.fields,
        ProfileFieldViewModel(
          value: 'lorem ipsum dolor sit amet ' * 20,
          label: 'Very long field',
          valueDirection: TextDirection.ltr,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            profile: profile,
            mediaByTab: {
              ProfileTab.posts: const ProfileRepository().loadMedia(
                ProfileTab.posts,
              ),
            },
            tab: ProfileTab.posts,
            onTabChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
  });
}
