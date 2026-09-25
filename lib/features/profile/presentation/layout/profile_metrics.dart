import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Every fixed dimension of the profile header, resolved once per layout from
/// the viewport size and the system insets.
///
/// Nothing downstream reads [MediaQuery] or hardcodes a device coordinate: the
/// widgets ask this object, and this object derives its values from the screen
/// it was given. That is what keeps the header correct on a 4.7" phone, a
/// tablet and in landscape without a single magic number in the widget tree.
@immutable
class ProfileMetrics {
  const ProfileMetrics({
    required this.screen,
    required this.topInset,
    required this.bottomInset,
    required this.textScale,
  });

  /// Depends only on the size, padding and text scale aspects of
  /// [MediaQuery], so the keyboard, brightness or gesture insets changing
  /// does not rebuild whoever asks.
  factory ProfileMetrics.of(BuildContext context) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    return ProfileMetrics(
      screen: MediaQuery.sizeOf(context),
      topInset: padding.top,
      bottomInset: padding.bottom,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
  }

  final Size screen;
  final double topInset;
  final double bottomInset;
  final double textScale;

  // --- Invariants measured from the reference recording -------------------

  static const double toolbarHeight = 56;
  static const double horizontalPadding = 12;

  /// Distance from the status bar to the top of the resting avatar.
  static const double restingAvatarTopGap = 40;

  /// Gap between the resting avatar and the name.
  static const double avatarToIdentityGap = 16;

  /// Unscaled height of the name + status block (see [AppTextStyles]: the
  /// block is laid out once at its largest size and scaled from there).
  static const double identityBlockHeight = 52;

  static const double identityToActionsGap = 22;
  static const double coverToActionsGap = 30;
  static const double actionsHeight = 64;
  static const double actionsGap = 10;
  static const double headerBottomPadding = 12;

  /// Name scale relative to the 24px base, per header state.
  static const double expandedNameScale = 1;
  static const double restingNameScale = 20 / 24;
  static const double collapsedNameScale = 19 / 24;

  /// Left inset of the name while it is still centred under the avatar.
  static const double identityLeftExpanded = 20;

  /// Left edge of the name in the collapsed app bar, just past the leading
  /// toolbar button (a 48dp icon button inset by 4dp).
  static const double identityLeftDocked = 58;

  /// Size the avatar shrinks to as it is pulled into the black hole.
  static const double swallowedAvatarDiameter = 30;

  /// How far below the hole's centre the swallowed avatar settles, so the
  /// black sits on its top like the cap of a bulb.
  static const double swallowedAvatarSink = 8;

  /// The hole when it first appears: a small dot, like a camera cutout.
  static const double swallowDotDiameter = 22;

  /// The hole once it has opened up to take the avatar in.
  static const double swallowHoleDiameter = 40;

  /// How far the hole sinks towards the avatar as it opens up.
  static const double swallowHoleDrop = 10;

  /// Blur on the avatar by the time it is fully inside the hole.
  static const double swallowMaxBlur = 8;

  /// How far the hole's black creeps down the photo, 1 being its upper half;
  /// kept below 1 so the photo still shows inside the hole's belly.
  static const double swallowMaxInk = 0.5;

  /// Corner radius of the rounded "modern" square the avatar passes through
  /// on its way to the full-bleed cover.
  static const double coverCornerRadius = 30;

  /// Width of that rounded square relative to the screen.
  static const double galleryWaypointWidthFactor = 0.8;

  /// Strongest blur at the bottom edge of the fully open cover.
  static const double coverBlurSigma = 16;

  /// Furthest the cover stretches when the list is pulled past its top.
  static const double maxStretch = 240;

  /// Story segments over the open cover: gap below the status bar and inset
  /// from both screen edges.
  static const double storySegmentsTopGap = 7;
  static const double storySegmentsHorizontalInset = 10;

  /// Gap between the name and the status line under it.
  static const double nameToStatusGap = 3;

  /// How much narrower the action row gets as it squashes vertically, at its
  /// flattest.
  static const double actionsSquashWidthFactor = 0.12;

  /// Opacity below which the fading action row stops taking taps.
  static const double actionsTapOpacityThreshold = 0.05;

  /// Radius of the light around the resting avatar, relative to the screen
  /// width.
  static const double headerGlowRadiusFactor = 0.75;

  /// Where the open cover's top scrim ends and its bottom scrim begins, as
  /// fractions of the cover's height.
  static const List<double> coverScrimStops = <double>[0, 0.18, 0.55, 1];

  /// Span the baked cover blur is calibrated against before the header has
  /// been measured.
  static const double coverBlurFallbackSpan = 400;

  // --- Derived extents -----------------------------------------------------

  /// Header height when fully collapsed: a plain pinned app bar.
  double get collapsedExtent => topInset + toolbarHeight;

  /// Vertical rhythm multiplier. The gaps below were measured on a ~850dp
  /// tall phone; on anything shorter (a small phone, landscape, a split
  /// window) they are tightened proportionally so the resting header never
  /// grows to swallow the screen. Taller screens keep the measured spacing
  /// rather than stretching it.
  double get tightness => (screen.height / 780).clamp(0.62, 1.0);

  /// Avatar size is driven by the width, but also capped against the height
  /// so a landscape viewport does not get a 180dp circle.
  double get restingAvatarDiameter =>
      math.min(screen.width * 0.215, screen.height * 0.16).clamp(56.0, 112.0);

  double get restingAvatarTop => topInset + restingAvatarTopGap * tightness;

  /// Header height at rest, i.e. the state the screen opens in: circular
  /// avatar, centred name, action buttons.
  double get restingExtent =>
      restingAvatarTop +
      restingAvatarDiameter +
      avatarToIdentityGap * tightness +
      identityBlockHeight * textScale +
      identityToActionsGap * tightness +
      actionsHeight +
      headerBottomPadding;

  /// Height of the full-bleed cover photo in the expanded state. The photo is
  /// square, so the width is the natural cap; the height fraction grows on
  /// landscape viewports where 52% would leave the gallery barely larger than
  /// the resting state.
  double get coverHeight => math.min(
    screen.width,
    screen.height * (screen.height >= screen.width ? 0.52 : 0.74),
  );

  /// Header height when the cover gallery is open. Reached by over-dragging
  /// the list at the top, not by normal scrolling.
  double get expandedExtent => math.max(
    restingExtent,
    coverHeight +
        coverToActionsGap * tightness +
        actionsHeight +
        headerBottomPadding,
  );

  /// Scroll distance between the expanded and resting states. The scroll view
  /// starts at this offset, so offset 0 means "gallery open".
  ///
  /// Zero on a viewport with no room for a gallery (and on the degenerate
  /// 0x0 window Android hands us for the very first frame), in which case the
  /// header simply has no expanded state.
  double get galleryRange => expandedExtent - restingExtent;

  /// Whether this viewport was measured at all. Android reports a 0x0 window
  /// before the first real layout pass, and metrics derived from it are
  /// meaningless.
  bool get isMeasured => screen.width > 0 && screen.height > 0;

  double get restingIdentityTop =>
      restingAvatarTop +
      restingAvatarDiameter +
      avatarToIdentityGap * tightness;

  double get expandedIdentityTop =>
      expandedExtent -
      headerBottomPadding -
      actionsHeight -
      identityToActionsGap * 0.4 * tightness -
      identityBlockHeight * textScale;

  /// Vertical position at which the name stops following the scroll and sits
  /// centred in the app bar, beside the docked avatar.
  double get dockedIdentityTop =>
      topInset +
      (toolbarHeight - identityBlockHeight * collapsedNameScale * textScale) /
          2;

  /// Where the black hole sits: top centre, over the status bar, where a
  /// phone's camera cutout usually is.
  Offset get swallowCenter =>
      Offset(screen.width / 2, math.max(14.0, topInset / 2));

  // --- Media section -------------------------------------------------------

  static const double gridSpacing = 3;
  static const double gridMargin = 6;
  static const double gridTileAspectRatio = 0.78;
  static const double gridCornerRadius = 12;

  /// Distance of the pin and the badges from a tile's edges.
  static const double mediaOverlayInset = 6;
  static const double mediaPinIconSize = 16;
  static const double mediaPinShadowBlur = 4;

  /// Height of a tile's bottom scrim, as a fraction of the tile.
  static const double mediaScrimHeightFraction = 0.34;

  static const double mediaBadgeRadius = 7;
  static const double mediaBadgeHorizontalPadding = 5;
  static const double mediaBadgeVerticalPadding = 2;
  static const double mediaBadgeIconSize = 13;
  static const double mediaBadgeIconGap = 3;

  /// Two columns on a phone, three on a large phone or small tablet, four on
  /// a wide tablet, so tiles never grow oversized past ~600dp.
  int get gridColumnCount {
    if (screen.width >= 1000) return 4;
    if (screen.width >= 600) return 3;
    return 2;
  }

  static const double tabsBarHeight = 58;

  /// The Posts / Archived Posts selector: its rounded track, the gap between
  /// the track and the highlight, and the padding around each label.
  static const double tabsTrackHeight = 40;
  static const double tabsTrackInset = 4;
  static const double tabsLabelPadding = 16;
  static const double tabsHorizontalPadding = 12;

  /// The selector's labels follow the user's text size up to this factor.
  static const double tabsMaxTextScale = 1.6;

  static const double infoCardRadius = 16;

  /// Gap between the bottom of the header and the information card.
  static const double infoCardTopGap = 10;

  /// Navigation chrome follows the user's text size, but only so far: past
  /// about 1.3x the labels stop being what makes the bar usable and the icons
  /// take over, so the bar grows to that point and then holds.
  static const double navMaxTextScale = 1.3;

  double get navTextScale => math.min(textScale, navMaxTextScale);

  double get bottomNavHeight => 62 + math.max(0, navTextScale - 1) * 22;

  // --- Floating controls ---------------------------------------------------

  /// Gap between the bottom safe area and the navigation bar.
  static const double navBottomGap = 10;

  /// Gap between the navigation bar and the add-post button stacked on it.
  static const double floatingStackGap = 9;

  /// Room left between the last row of content and the add-post button once
  /// the list is scrolled to its end.
  static const double floatingContentGap = 12;

  /// Unread badge position relative to its destination icon.
  static const double navBadgeTop = -4;
  static const double navBadgeStart = 13;

  /// Where the add-post button waits while hidden, in multiples of its own
  /// size below its resting place.
  static const Offset addPostHiddenSlide = Offset(0, 1.6);

  /// Side margin of the floating controls; grows with the screen width.
  double get floatingHorizontalMargin => math.max(16.0, screen.width * 0.09);

  /// Distance from the screen bottom to the navigation bar.
  double get navBottom => bottomInset + navBottomGap;

  /// Distance from the screen bottom to the add-post / notice slot.
  double get floatingStackBottom =>
      navBottom + bottomNavHeight + floatingStackGap;

  /// Height of the add-post pill: 10dp vertical padding around the taller of
  /// its 19dp icon and its 14sp label (line height 1.1).
  double get addPostButtonHeight => 20 + math.max(19.0, 15.4 * textScale);

  /// Bottom padding a scrollable needs so its last item can scroll clear of
  /// every floating control.
  double get floatingControlsClearance =>
      floatingStackBottom + addPostButtonHeight + floatingContentGap;

  @override
  bool operator ==(Object other) =>
      other is ProfileMetrics &&
      other.screen == screen &&
      other.topInset == topInset &&
      other.bottomInset == bottomInset &&
      other.textScale == textScale;

  @override
  int get hashCode => Object.hash(screen, topInset, bottomInset, textScale);
}
