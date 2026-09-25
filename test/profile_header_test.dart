import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_profile/app/app.dart';
import 'package:telegram_profile/core/constants/theme/app_colors.dart';
import 'package:telegram_profile/features/profile/presentation/layout/header_geometry.dart';
import 'package:telegram_profile/features/profile/presentation/layout/profile_metrics.dart';
import 'package:telegram_profile/features/profile/presentation/screens/profile_screen.dart';
import 'package:telegram_profile/features/profile/presentation/screens/story_preview.dart';
import 'package:telegram_profile/features/profile/presentation/scroll/profile_scroll_physics.dart';
import 'package:telegram_profile/features/profile/presentation/widgets/header/profile_header_sliver.dart';
import 'package:telegram_profile/features/shell/presentation/widgets/add_post_button.dart';

const ProfileMetrics _metrics = ProfileMetrics(
  screen: Size(384, 854),
  topInset: 48,
  bottomInset: 24,
  textScale: 1,
);

void main() {
  group('ProfileMetrics', () {
    test('orders the three header extents', () {
      expect(_metrics.collapsedExtent, lessThan(_metrics.restingExtent));
      expect(_metrics.restingExtent, lessThan(_metrics.expandedExtent));
      expect(_metrics.galleryRange, greaterThan(0));
    });

    test('keeps a usable gallery on every viewport it is likely to meet', () {
      const viewports = <Size>[
        Size(320, 568), // smallest phone worth supporting
        Size(360, 640), // Small Phone profile
        Size(384, 854), // Pixel 8 Pro
        Size(440, 956), // Pixel 9 Pro XL
        Size(834, 1112), // tablet
        Size(854, 384), // landscape phone
        Size(1112, 834), // landscape tablet
      ];
      for (final size in viewports) {
        final metrics = ProfileMetrics(
          screen: size,
          topInset: 24,
          bottomInset: 16,
          textScale: 1,
        );
        expect(
          metrics.restingExtent,
          lessThan(size.height * 0.75),
          reason: 'resting header swallows $size',
        );
        expect(
          metrics.expandedExtent,
          lessThanOrEqualTo(size.height),
          reason: 'expanded header overflows $size',
        );
        expect(
          metrics.galleryRange,
          greaterThan(40),
          reason: 'no room to pull the gallery open on $size',
        );
      }
    });

    test('degrades safely on the 0x0 window Android reports first', () {
      const zero = ProfileMetrics(
        screen: Size.zero,
        topInset: 0,
        bottomInset: 0,
        textScale: 1,
      );
      expect(zero.isMeasured, isFalse);
      expect(zero.galleryRange, 0);
      expect(zero.expandedExtent, greaterThanOrEqualTo(zero.restingExtent));
    });
  });

  group('HeaderGeometry', () {
    HeaderGeometry at(double extent) =>
        HeaderGeometry.resolve(metrics: _metrics, extent: extent);

    test('rests with a centred circular avatar', () {
      final geometry = at(_metrics.restingExtent);
      expect(geometry.galleryProgress, 0);
      expect(geometry.dockProgress, 0);
      expect(geometry.avatarRect.width, _metrics.restingAvatarDiameter);
      expect(geometry.avatarCornerRadius, _metrics.restingAvatarDiameter / 2);
      expect(geometry.avatarRect.center.dx, _metrics.screen.width / 2);
      expect(geometry.identityAlignX, 0.5);
    });

    test('opens into a full-bleed square-cornered cover', () {
      final geometry = at(_metrics.expandedExtent);
      expect(geometry.galleryProgress, 1);
      expect(geometry.avatarRect.left, 0);
      expect(geometry.avatarRect.width, _metrics.screen.width);
      expect(geometry.avatarCornerRadius, 0);
      expect(geometry.identityAlignX, 0);
    });

    test('stays round early and relaxes its corners gradually', () {
      final grow = at(_metrics.restingExtent + _metrics.galleryRange * 0.15);
      expect(
        grow.avatarCornerRadius,
        greaterThan(grow.avatarRect.shortestSide / 2 * 0.9),
      );
      expect(
        grow.avatarRect.width,
        greaterThan(_metrics.restingAvatarDiameter),
      );

      final morphing = at(_metrics.restingExtent + _metrics.galleryRange * 0.7);
      expect(morphing.avatarCornerRadius, greaterThan(0));
      expect(
        morphing.avatarCornerRadius,
        lessThan(morphing.avatarRect.shortestSide / 2),
      );
    });

    test('swallows the avatar before the action row collapses', () {
      final halfway =
          _metrics.restingExtent -
          (_metrics.restingExtent - _metrics.collapsedExtent) *
              HeaderGeometry.swallowEnd;
      final swallowed = at(halfway);
      expect(swallowed.isAvatarVisible, isFalse);
      expect(swallowed.swallowRect.isEmpty, isTrue);
      expect(swallowed.actionsOpacity, 1);
      expect(swallowed.actionsScaleY, 1);

      final midSwallow = at(
        _metrics.restingExtent -
            (_metrics.restingExtent - _metrics.collapsedExtent) * 0.2,
      );
      expect(midSwallow.avatarBlurSigma, greaterThan(0));
      expect(midSwallow.swallowRect.isEmpty, isFalse);
      expect(
        midSwallow.avatarRect.width,
        lessThan(_metrics.restingAvatarDiameter),
      );
    });

    test('collapses to the name and status only', () {
      final geometry = at(_metrics.collapsedExtent);
      expect(geometry.dockProgress, 1);
      expect(geometry.avatarOpacity, 0);
      expect(geometry.actionsOpacity, 0);
      expect(geometry.identityLeft, ProfileMetrics.identityLeftDocked);
      expect(geometry.identityTop, closeTo(_metrics.dockedIdentityTop, 0.01));
      expect(geometry.identityAlignX, 0);
    });

    test('keeps the action row on the header bottom edge in every state', () {
      for (final extent in <double>[
        _metrics.collapsedExtent,
        _metrics.restingExtent,
        _metrics.expandedExtent,
      ]) {
        expect(
          at(extent).actionsTop,
          extent -
              ProfileMetrics.headerBottomPadding -
              ProfileMetrics.actionsHeight,
        );
      }
    });

    test('grows the cover with the overscroll stretch', () {
      final stretched = at(_metrics.expandedExtent + 60);
      expect(stretched.avatarRect.height, _metrics.expandedExtent + 60);
      expect(stretched.galleryProgress, 1);
    });

    test('never jumps: every value is continuous across the range', () {
      HeaderGeometry? previous;
      for (
        var extent = _metrics.collapsedExtent;
        extent <= _metrics.expandedExtent;
        extent += 0.5
      ) {
        final current = at(extent);
        if (previous != null) {
          expect(
            (current.avatarRect.top - previous.avatarRect.top).abs(),
            lessThan(4),
          );
          expect(
            (current.avatarRect.width - previous.avatarRect.width).abs(),
            lessThan(6),
          );
          expect(
            (current.identityTop - previous.identityTop).abs(),
            lessThan(2),
          );
          expect(
            (current.identityScale - previous.identityScale).abs(),
            lessThan(0.02),
          );
          expect(
            (current.avatarOpacity - previous.avatarOpacity).abs(),
            lessThan(0.05),
          );
        }
        previous = current;
      }
    });
  });

  group('ProfileScrollPhysics', () {
    const physics = ProfileScrollPhysics(
      restingOffset: 150,
      parent: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    );

    ScrollMetrics metricsAt(double pixels) => FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 2000,
      pixels: pixels,
      viewportDimension: 800,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 3,
    );

    double settle(Simulation simulation) {
      var t = 0.0;
      while (t < 10 && !simulation.isDone(t)) {
        t += 1 / 60;
      }
      return simulation.x(t);
    }

    test('a fling towards the top stops at the resting state', () {
      final simulation = physics.createBallisticSimulation(
        metricsAt(900),
        -6000,
      );
      expect(simulation, isNotNull);
      expect(settle(simulation!), greaterThanOrEqualTo(150));
    });

    test('a deliberate drag inside the gallery is left alone', () {
      final simulation = physics.createBallisticSimulation(metricsAt(40), -200);
      // Either it is allowed to run to the open position or there is nothing
      // to simulate; what matters is that it is not floored at the resting
      // state the way a fling is.
      if (simulation != null) {
        expect(settle(simulation), lessThan(150));
      }
    });

    test('scrolling away from the top is unaffected', () {
      final simulation = physics.createBallisticSimulation(
        metricsAt(900),
        4000,
      );
      expect(settle(simulation!), greaterThan(900));
    });
  });

  group('profile list', () {
    late ProfileMetrics metrics;

    Future<ScrollPosition> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      metrics = ProfileMetrics(
        screen: tester.view.physicalSize / tester.view.devicePixelRatio,
        topInset: 0,
        bottomInset: 0,
        textScale: 1,
      );

      await tester.pumpWidget(const TelegramProfileApp());
      await tester.pump();
      return tester
          .state<NestedScrollViewState>(find.byType(NestedScrollView))
          .outerController
          .position;
    }

    testWidgets('opens on the full cover photo', (tester) async {
      final position = await pumpApp(tester);
      expect(position.maxScrollExtent, greaterThan(metrics.galleryRange));
      expect(position.pixels, 0);
    });

    double addPostOpacity(WidgetTester tester) =>
        tester.widget<AddPostButton>(find.byType(AddPostButton)).opacity;

    testWidgets('add post appears only once the posts scroll in', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(addPostOpacity(tester), 0);

      await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(addPostOpacity(tester), 1);
    });

    testWidgets('other destinations say they are unavailable', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Chats'));
      await tester.pump();

      expect(find.text('This page is not available yet'), findsOneWidget);
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('This page is not available yet'), findsNothing);
    });

    testWidgets('header buttons explain themselves in the floating notice', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Edit Info'));
      await tester.pump();

      expect(find.text('Not part of this demo yet'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Not part of this demo yet'), findsNothing);
    });

    /// The fully opaque page-coloured layer that covers the blue header.
    Finder pageColouredHeader() => find.descendant(
      of: find.byType(ProfileHeaderSliver),
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == AppColors.scaffold,
      ),
    );

    testWidgets('status shows the story count only at the end of the page', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('online'), findsOneWidget);
      expect(find.text('4 stories'), findsNothing);

      expect(pageColouredHeader(), findsNothing);

      await tester.drag(find.byType(NestedScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text('4 stories'), findsOneWidget);
      expect(find.text('online'), findsNothing);
      expect(pageColouredHeader(), findsOneWidget);

      await tester.drag(find.byType(NestedScrollView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.text('online'), findsOneWidget);
      expect(pageColouredHeader(), findsNothing);
    });

    Future<void> goToRest(WidgetTester tester, ScrollPosition position) async {
      position.jumpTo(metrics.galleryRange);
      await tester.pump();
    }

    Offset avatarCentre(double extent) => HeaderGeometry.resolve(
      metrics: metrics,
      extent: extent,
    ).avatarRect.center;

    testWidgets('tapping the circular avatar morphs it into the cover', (
      tester,
    ) async {
      final position = await pumpApp(tester);
      await goToRest(tester, position);

      await tester.tapAt(avatarCentre(metrics.restingExtent));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(position.pixels, inExclusiveRange(0, metrics.galleryRange));

      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      expect(find.byType(StoryPreview), findsNothing);
    });

    testWidgets('tapping the open cover does nothing', (tester) async {
      final position = await pumpApp(tester);

      await tester.tapAt(avatarCentre(metrics.expandedExtent));
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      expect(find.byType(StoryPreview), findsNothing);
    });

    testWidgets('a fling back to the top settles at rest, not on the cover', (
      tester,
    ) async {
      final position = await pumpApp(tester);

      position.jumpTo(position.maxScrollExtent);
      await tester.pump();

      // A short drag plus a fast release: the momentum has to die at the
      // resting header. A long drag is allowed to pull the cover open.
      await tester.fling(
        find.byType(NestedScrollView),
        const Offset(0, 80),
        8000,
      );
      await tester.pumpAndSettle();

      expect(position.pixels, closeTo(metrics.galleryRange, 1));
    });

    testWidgets('a deliberate pull at the top opens and stays open', (
      tester,
    ) async {
      final position = await pumpApp(tester);
      await goToRest(tester, position);

      final gesture = await tester.startGesture(const Offset(180, 500));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, 14));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(position.pixels, 0);
    });

    testWidgets('an abandoned half pull snaps back to rest', (tester) async {
      final position = await pumpApp(tester);
      await goToRest(tester, position);

      final gesture = await tester.startGesture(const Offset(180, 500));
      // Roughly a third of the way into the gallery, released without speed.
      final pull = metrics.galleryRange / 3;
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(0, pull / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(position.pixels, closeTo(metrics.galleryRange, 1));
    });

    Future<void> slowDragUp(WidgetTester tester, double distance) async {
      final gesture = await tester.startGesture(const Offset(180, 600));
      // Many small steps with a pause at the end so the release carries no
      // speed and only the position decides.
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(0, -distance / 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('a release nearer the resting place lets the avatar back out', (
      tester,
    ) async {
      final position = await pumpApp(tester);
      await goToRest(tester, position);
      final swallowed = HeaderGeometry.swallowOffset(metrics);

      await slowDragUp(tester, (swallowed - metrics.galleryRange) * 0.35);

      expect(position.pixels, closeTo(metrics.galleryRange, 1));
    });

    testWidgets('a release nearer the hole finishes the swallow', (
      tester,
    ) async {
      final position = await pumpApp(tester);
      await goToRest(tester, position);
      final swallowed = HeaderGeometry.swallowOffset(metrics);

      await slowDragUp(tester, (swallowed - metrics.galleryRange) * 0.65);

      expect(position.pixels, closeTo(swallowed, 1));
    });
  });
}
