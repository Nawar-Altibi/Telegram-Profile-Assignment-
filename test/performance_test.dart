import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_profile/app/app.dart';
import 'package:telegram_profile/core/widgets/frosted_surface.dart';
import 'package:telegram_profile/features/profile/presentation/layout/profile_metrics.dart';
import 'package:telegram_profile/features/profile/presentation/widgets/grid/media_tile.dart';
import 'package:telegram_profile/features/profile/presentation/widgets/header/blurred_cover.dart';
import 'package:telegram_profile/features/profile/presentation/widgets/header/header_actions.dart';
import 'package:telegram_profile/features/profile/presentation/widgets/header/header_identity.dart';
import 'package:telegram_profile/features/profile/presentation/widgets/header/profile_header_sliver.dart';
import 'package:telegram_profile/features/profile/presentation/widgets/header/swallowed_avatar.dart';
import 'package:telegram_profile/features/shell/presentation/widgets/floating_bottom_nav.dart';

/// Rebuild / paint budget that the assignment asks us to keep during scroll.
///
/// These are not DevTools numbers - they are the invariants those numbers
/// come from. If a later change puts the scroll offset into a ChangeNotifier
/// that the grid listens to, or drops the per-tile [RepaintBoundary], these
/// fail before a reviewer has to open the timeline.
void main() {
  Future<void> pumpPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TelegramProfileApp());
    await tester.pump();
  }

  testWidgets('the grid stays lazy while the list is flung', (tester) async {
    await pumpPhone(tester);

    final list = find.byType(NestedScrollView);
    var peak = tester.widgetList<MediaTile>(find.byType(MediaTile)).length;

    for (var i = 0; i < 8; i++) {
      await tester.fling(list, const Offset(0, -700), 3000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final built = tester.widgetList<MediaTile>(find.byType(MediaTile)).length;
      if (built > peak) peak = built;
    }
    await tester.pumpAndSettle();

    // Two columns: a well-behaved lazy grid on this viewport never has more
    // than a couple of extra rows mounted.
    expect(peak, greaterThan(0));
    expect(peak, lessThanOrEqualTo(10));
  });

  testWidgets('every on-screen tile is its own repaint boundary', (
    tester,
  ) async {
    await pumpPhone(tester);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<MediaTile>(find.byType(MediaTile));
    expect(tiles, isNotEmpty);
    for (final tile in tiles) {
      // The grid's builder delegate provides the boundary; the nearest one
      // above the tile must wrap that tile alone, not the whole list.
      final tileBox = tester.renderObject<RenderBox>(find.byWidget(tile));
      RenderObject? node = tileBox.parent;
      while (node != null && node is! RenderRepaintBoundary) {
        node = node.parent;
      }
      expect(node, isNotNull);
      expect((node! as RenderBox).size, tileBox.size);
      expect(
        find.descendant(
          of: find.byWidget(tile),
          matching: find.byType(RepaintBoundary),
        ),
        findsNothing,
        reason: 'a second boundary inside the tile is only an extra layer',
      );
    }
  });

  testWidgets('the blurred bar is clipped to its own layer', (tester) async {
    await pumpPhone(tester);

    expect(find.byType(FrostedSurface), findsWidgets);
    final surface = tester.widget<FrostedSurface>(
      find.byType(FrostedSurface).first,
    );
    expect(
      find.descendant(
        of: find.byWidget(surface),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byWidget(surface),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('scrolling does not rebuild the header sliver widget', (
    tester,
  ) async {
    await pumpPhone(tester);

    final before = tester.widget<ProfileHeaderSliver>(
      find.byType(ProfileHeaderSliver),
    );

    await tester.drag(find.byType(NestedScrollView), const Offset(0, -400));
    await tester.pump();
    await tester.drag(find.byType(NestedScrollView), const Offset(0, 200));
    await tester.pump();

    final after = tester.widget<ProfileHeaderSliver>(
      find.byType(ProfileHeaderSliver),
    );
    expect(
      identical(before, after),
      isTrue,
      reason: 'scroll must not reconstruct the header sliver',
    );
  });

  testWidgets('stretching the cover reuses the cached header parts', (
    tester,
  ) async {
    await pumpPhone(tester);

    HeaderNameRow nameRow() =>
        tester.widget<HeaderNameRow>(find.byType(HeaderNameRow));
    final before = nameRow();

    final gesture = await tester.startGesture(const Offset(180, 400));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(nameRow(), before), isTrue);
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(identical(nameRow(), before), isTrue);
    await tester.pumpAndSettle();
    expect(identical(nameRow(), before), isTrue);
  });

  ScrollPosition outer(WidgetTester tester) => tester
      .state<NestedScrollViewState>(find.byType(NestedScrollView))
      .outerController
      .position;

  Finder actionBlurs() => find.descendant(
    of: find.byType(HeaderActions),
    matching: find.byType(BackdropFilter),
  );

  testWidgets('the action row blurs only while the cover is behind it', (
    tester,
  ) async {
    await pumpPhone(tester);
    final metrics = ProfileMetrics.of(
      tester.element(find.byType(NestedScrollView)),
    );

    // Opens on the full cover photo.
    expect(actionBlurs(), findsNWidgets(3));

    outer(tester).jumpTo(metrics.galleryRange);
    await tester.pump();
    expect(find.byType(HeaderActions), findsOneWidget);
    expect(actionBlurs(), findsNothing);

    // Half way through docking the row fades without an opacity layer.
    final double dockSpan = metrics.restingExtent - metrics.collapsedExtent;
    outer(tester).jumpTo(metrics.galleryRange + dockSpan * 0.7);
    await tester.pump();
    expect(actionBlurs(), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ProfileHeaderSliver),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('the swallow paints without clip or filter layers', (
    tester,
  ) async {
    await pumpPhone(tester);
    final metrics = ProfileMetrics.of(
      tester.element(find.byType(NestedScrollView)),
    );
    final double dockSpan = metrics.restingExtent - metrics.collapsedExtent;

    for (final double t in <double>[0.1, 0.25, 0.35, 0.45, 0.49]) {
      outer(tester).jumpTo(metrics.galleryRange + dockSpan * t);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(SwallowedAvatar), findsOneWidget);
    }
    final swallow = find.byType(SwallowedAvatar);
    for (final Type layer in <Type>[ClipPath, ClipOval, ImageFiltered]) {
      expect(
        find.descendant(of: swallow, matching: find.byType(layer)),
        findsNothing,
      );
    }
  });

  testWidgets('the swallow painter draws the photo sharp and blurred', (
    tester,
  ) async {
    final ui.Image photo = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 64, 64),
        Paint()..color = const Color(0xFF3366CC),
      );
      final picture = recorder.endRecording();
      final source = await picture.toImage(64, 64);
      picture.dispose();
      return source;
    }))!;
    addTearDown(photo.dispose);

    for (final double contact in <double>[0, 0.5, 1]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(
            child: SwallowedAvatar(
              hole: Rect.fromCircle(center: const Offset(200, 20), radius: 20),
              avatar: Rect.fromCircle(
                center: Offset(200, 90 - contact * 40),
                radius: 30,
              ),
              image: photo,
              contact: contact,
              ink: contact * 0.5,
              blurSigma: contact * 8,
              opacity: 1 - contact * 0.5,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('switching tabs does not rebuild the shell', (tester) async {
    await pumpPhone(tester);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final before = tester.widget<FloatingBottomNav>(
      find.byType(FloatingBottomNav),
    );

    await tester.tap(find.text('Archived Posts'));
    await tester.pumpAndSettle();

    final tabs = DefaultTabController.maybeOf(
      tester.element(find.byType(TabBarView)),
    );
    final view = tester.widget<TabBarView>(find.byType(TabBarView));
    expect((tabs ?? view.controller)!.index, 1);
    final after = tester.widget<FloatingBottomNav>(
      find.byType(FloatingBottomNav),
    );
    expect(identical(before, after), isTrue);
  });

  test('the cover blur is baked into a small image once', () async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 640, 640),
      Paint()..color = const Color(0xFF3366CC),
    );
    final picture = recorder.endRecording();
    final source = await picture.toImage(640, 640);

    final baked = await bakeBlurredCover(source, sigma: 3);
    expect(baked.width, bakedCoverWidth);
    expect(baked.height, bakedCoverWidth);

    baked.dispose();
    source.dispose();
    picture.dispose();
  });
}
