import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../../core/constants/theme/app_colors.dart';
import '../../layout/header_geometry.dart';
import '../../layout/profile_metrics.dart';
import '../../view_models/profile_view_model.dart';
import 'blurred_cover.dart';
import 'header_actions.dart';
import 'header_identity.dart';
import 'header_top_bar.dart';
import 'story_segments.dart';
import 'swallowed_avatar.dart';

/// Pinned sliver that morphs between the three profile header states.
///
/// Rebuild discipline, which is the whole reason this is a delegate rather
/// than a scroll listener:
///
///  * The state builds each expensive subtree - the photo, the action row,
///    the app bar icons - once into [_HeaderParts], and only rebuilds them
///    when the profile, the metrics or the baked blur change. The overscroll
///    stretch creates a new delegate every frame, but it carries the same
///    parts instance.
///  * The delegate's [build] runs inside a [LayoutBuilder], so it re-runs
///    during layout only when the sliver's extent actually changes, and it
///    reads that extent directly instead of deriving it from `shrinkOffset`
///    (which does not account for the overscroll stretch).
///  * Per frame it only recreates cheap positioning widgets around those
///    cached children. Because the child instances are identical,
///    `Element.updateChild` short-circuits and none of those subtrees rebuild.
///  * Nothing inside the layout-time build registers an inherited dependency
///    of its own or moves a [GlobalKey]; the blurred cover is baked here in
///    the state, outside layout.
class ProfileHeaderSliver extends StatefulWidget {
  const ProfileHeaderSliver({
    super.key,
    required this.metrics,
    required this.profile,
    required this.actions,
    required this.stretch,
    required this.showStoryCount,
    this.onAvatarTap,
  });

  final ProfileMetrics metrics;
  final ProfileViewModel profile;
  final List<HeaderAction> actions;
  final ValueNotifier<double> stretch;

  /// True while the page is scrolled to its end; the status line then shows
  /// the story count instead of the presence text.
  final ValueListenable<bool> showStoryCount;
  final VoidCallback? onAvatarTap;

  @override
  State<ProfileHeaderSliver> createState() => _ProfileHeaderSliverState();
}

class _ProfileHeaderSliverState extends State<ProfileHeaderSliver> {
  _HeaderParts? _parts;

  ImageProvider? _coverProvider;
  ImageStream? _coverStream;
  late final ImageStreamListener _coverListener = ImageStreamListener(
    _onCoverImage,
  );

  /// The decoded photo, kept so the blur can be re-baked for new metrics and
  /// painted directly by [SwallowedAvatar].
  ImageInfo? _coverSource;
  ui.Image? _coverBlurred;
  int _bakeGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.stretch.addListener(_onStretch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveCover();
  }

  @override
  void didUpdateWidget(ProfileHeaderSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stretch != widget.stretch) {
      oldWidget.stretch.removeListener(_onStretch);
      widget.stretch.addListener(_onStretch);
    }
    if (oldWidget.profile != widget.profile) _resolveCover();
    if (oldWidget.metrics != widget.metrics) _bake();
    if (oldWidget.metrics != widget.metrics ||
        oldWidget.profile != widget.profile ||
        oldWidget.actions != widget.actions ||
        oldWidget.showStoryCount != widget.showStoryCount) {
      _parts = null;
    }
  }

  @override
  void dispose() {
    widget.stretch.removeListener(_onStretch);
    _coverStream?.removeListener(_coverListener);
    _coverSource?.dispose();
    _coverBlurred?.dispose();
    super.dispose();
  }

  void _onStretch() {
    if (mounted) setState(() {});
  }

  void _resolveCover() {
    final ImageProvider provider = widget.profile.avatar;
    if (provider == _coverProvider) return;
    _coverProvider = provider;
    _coverStream?.removeListener(_coverListener);
    _coverStream = provider.resolve(createLocalImageConfiguration(context))
      ..addListener(_coverListener);
  }

  void _onCoverImage(ImageInfo info, bool synchronousCall) {
    final ImageInfo? previous = _coverSource;
    _coverSource = info;
    // The painter of the frame on screen may still hold the old image.
    if (synchronousCall) {
      _parts = null;
    } else {
      setState(() => _parts = null);
    }
    if (previous != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    _bake();
  }

  /// Blur in pixels of the baked copy that matches
  /// [ProfileMetrics.coverBlurSigma] on screen. The photo is square and
  /// drawn with [BoxFit.cover], so it spans the open cover's longer side.
  static double _bakedSigma(ProfileMetrics metrics) {
    final double span = math.max(metrics.screen.width, metrics.expandedExtent);
    final double reference = span > 0 ? span : 400;
    return ProfileMetrics.coverBlurSigma * bakedCoverWidth / reference;
  }

  Future<void> _bake() async {
    final ImageInfo? source = _coverSource;
    if (source == null) return;
    final int generation = ++_bakeGeneration;
    final ui.Image baked = await bakeBlurredCover(
      source.image,
      sigma: _bakedSigma(widget.metrics),
    );
    if (!mounted || generation != _bakeGeneration) {
      baked.dispose();
      return;
    }
    final ui.Image? previous = _coverBlurred;
    setState(() {
      _coverBlurred = baked;
      _parts = null;
    });
    if (previous != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  Widget build(BuildContext context) {
    final _HeaderParts parts = _parts ??= _HeaderParts(
      metrics: widget.metrics,
      profile: widget.profile,
      actions: widget.actions,
      showStoryCount: widget.showStoryCount,
      blurredCover: _coverBlurred,
      coverImage: _coverSource?.image,
    );
    return SliverPersistentHeader(
      pinned: true,
      delegate: _ProfileHeaderDelegate(
        metrics: widget.metrics,
        parts: parts,
        onAvatarTap: widget.onAvatarTap,
        stretch: widget.stretch.value,
      ),
    );
  }
}

/// The header's expensive subtrees, built once per configuration and shared
/// by every delegate created while the cover is being stretched.
class _HeaderParts {
  _HeaderParts({
    required ProfileMetrics metrics,
    required ProfileViewModel profile,
    required List<HeaderAction> actions,
    required ValueListenable<bool> showStoryCount,
    required ui.Image? blurredCover,
    required this.coverImage,
  }) : actionList = actions,
       cover = Image(
         image: profile.avatar,
         fit: BoxFit.cover,
         // Resampled at a new size every frame of the morph; mipmapped linear
         // sampling stays sharp without the cost of cubic filtering.
         filterQuality: FilterQuality.medium,
         gaplessPlayback: true,
       ),
       coverBlur = blurredCover == null
           ? null
           : RawImage(
               image: blurredCover,
               fit: BoxFit.cover,
               filterQuality: FilterQuality.medium,
             ),
       blurStartFraction = _blurStartFraction(metrics),
       background = _HeaderBackground(
         metrics: metrics,
         atPageEnd: showStoryCount,
       ),
       nameRow = HeaderNameRow(name: profile.displayName),
       status = HeaderStatusText(
         status: profile.statusText,
         stories: profile.storyCountText,
         showStories: showStoryCount,
       ),
       frostedActions = HeaderActions(actions: actions),
       flatActions = HeaderActions(actions: actions, frosted: false),
       topBar = HeaderTopBar(topInset: metrics.topInset),
       storySegments = StorySegments(count: profile.storyCount);

  final Widget cover;

  /// The decoded photo, painted by [SwallowedAvatar]. Null until decoded.
  final ui.Image? coverImage;

  /// Null until the blurred copy has been baked; the sharp photo shows alone
  /// until then.
  final Widget? coverBlur;

  /// Where, as a fraction of the open cover's height, the blur starts.
  final double blurStartFraction;
  final Widget background;
  final Widget nameRow;
  final Widget status;

  /// The action row over the cover photo, where the blur shows.
  final Widget frostedActions;

  /// The same row over the plain header gradient, tint only.
  final Widget flatActions;
  final List<HeaderAction> actionList;
  final Widget topBar;
  final Widget storySegments;

  /// At the top of the name.
  static double _blurStartFraction(ProfileMetrics metrics) {
    if (metrics.expandedExtent <= 0) return 1;
    return (metrics.expandedIdentityTop / metrics.expandedExtent).clamp(
      0.0,
      0.9,
    );
  }
}

/// Turns the header's current extent into a [HeaderGeometry] and positions
/// the prebuilt [_HeaderParts] from it. This runs every scrolled frame, so it
/// only moves and fades parts; it never builds them.
class _ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileHeaderDelegate({
    required this.metrics,
    required this.parts,
    required this.onAvatarTap,
    required this.stretch,
  });

  final ProfileMetrics metrics;
  final _HeaderParts parts;
  final VoidCallback? onAvatarTap;

  /// Extra pixels past the open cover. [NestedScrollView] never applies a
  /// stretch configuration, so the screen feeds the pull in directly.
  final double stretch;

  @override
  double get maxExtent => metrics.expandedExtent + stretch;

  @override
  double get minExtent => metrics.collapsedExtent;

  @override
  bool shouldRebuild(_ProfileHeaderDelegate oldDelegate) =>
      oldDelegate.metrics != metrics ||
      !identical(oldDelegate.parts, parts) ||
      oldDelegate.onAvatarTap != onAvatarTap ||
      oldDelegate.stretch != stretch;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = HeaderGeometry.resolve(
          metrics: metrics,
          extent: constraints.maxHeight,
        );
        return _buildLayers(geometry);
      },
    );
  }

  /// At rest both sides use the same inset, so the name sits on the avatar's
  /// centre at every width. The dock slide then moves only the left edge.
  double _identityLeft(HeaderGeometry geometry) {
    final double slide = (1 - geometry.identityAlignX * 2).clamp(0.0, 1.0);
    const double centered = ProfileMetrics.horizontalPadding;
    return centered + (geometry.identityLeft - centered) * slide;
  }

  Widget _buildLayers(HeaderGeometry geometry) {
    final anchor = Alignment(geometry.identityAlignX * 2 - 1, -1);
    final Rect avatar = geometry.avatarRect;

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(child: parts.background),
          if (!geometry.swallowRect.isEmpty)
            Positioned.fill(
              child: SwallowedAvatar(
                hole: geometry.swallowRect,
                avatar: avatar,
                image: parts.coverImage,
                contact: geometry.swallowContact,
                ink: geometry.avatarInk,
                blurSigma: geometry.avatarBlurSigma,
                opacity: geometry.avatarOpacity,
              ),
            )
          else if (geometry.isAvatarVisible)
            PositionedDirectional(
              start: avatar.left,
              top: avatar.top,
              width: avatar.width,
              height: avatar.height,
              child: GestureDetector(
                onTap: onAvatarTap,
                child: _avatar(geometry),
              ),
            ),
          if (geometry.storyIndicatorOpacity > 0)
            Positioned(
              top: metrics.topInset + ProfileMetrics.storySegmentsTopGap,
              left: ProfileMetrics.storySegmentsHorizontalInset,
              right: ProfileMetrics.storySegmentsHorizontalInset,
              child: Opacity(
                opacity: geometry.storyIndicatorOpacity,
                child: parts.storySegments,
              ),
            ),
          PositionedDirectional(
            top: geometry.identityTop,
            start: _identityLeft(geometry),
            end: ProfileMetrics.horizontalPadding,
            child: Align(
              alignment: anchor,
              heightFactor: 1,
              child: Transform.scale(
                scale: geometry.identityScale,
                alignment: anchor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Align(alignment: anchor, child: parts.nameRow),
                    const SizedBox(height: 3),
                    Align(alignment: anchor, child: parts.status),
                  ],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: geometry.actionsTop,
            start: ProfileMetrics.horizontalPadding,
            end: ProfileMetrics.horizontalPadding,
            height: ProfileMetrics.actionsHeight,
            child: IgnorePointer(
              ignoring: geometry.actionsOpacity < 0.05,
              child: geometry.actionsOpacity <= 0
                  ? const SizedBox.shrink()
                  : Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.diagonal3Values(
                        1 - (1 - geometry.actionsScaleY) * 0.12,
                        geometry.actionsScaleY,
                        1,
                      ),
                      child: _actions(geometry),
                    ),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: parts.topBar),
        ],
      ),
    );
  }

  /// The photo only reaches the action row once the gallery opens; before
  /// that the row sits on the flat header gradient and a blur would change
  /// nothing. The fade happens while docking, where the row is always flat,
  /// so it is folded into the tint instead of an [Opacity] layer.
  Widget _actions(HeaderGeometry geometry) {
    if (geometry.galleryProgress > 0) return parts.frostedActions;
    if (geometry.actionsOpacity >= 1) return parts.flatActions;
    return HeaderActions(
      actions: parts.actionList,
      frosted: false,
      opacity: geometry.actionsOpacity,
    );
  }

  /// The photo, clipped to its current shape. On the open cover a
  /// progressive blur rises from the bottom edge up to the name.
  Widget _avatar(HeaderGeometry geometry) {
    final Widget? blurred = parts.coverBlur;
    return ClipRRect(
      borderRadius: BorderRadius.circular(geometry.avatarCornerRadius),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          parts.cover,
          if (blurred != null && geometry.coverBlurOpacity > 0)
            CoverBlurMask(
              opacity: geometry.coverBlurOpacity,
              startFraction: parts.blurStartFraction,
              child: blurred,
            ),
          if (geometry.coverScrimOpacity > 0)
            _CoverScrim(opacity: geometry.coverScrimOpacity),
        ],
      ),
    );
  }
}

/// Blue header backdrop with a soft light radiating from behind the resting
/// avatar.
class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({required this.metrics, required this.atPageEnd});

  final ProfileMetrics metrics;

  /// True once the page is scrolled to its very end, where the status line
  /// reads "N stories". The blue then fades into the page colour so the
  /// collapsed bar blends with the content under it.
  final ValueListenable<bool> atPageEnd;

  /// Radius of the light around the avatar, relative to the screen width.
  static const double _glowRadiusFactor = 0.75;
  static const Duration _fade = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final glow = Rect.fromCircle(
      center: Offset(
        metrics.screen.width / 2,
        metrics.restingAvatarTop + metrics.restingAvatarDiameter / 2,
      ),
      radius: metrics.screen.width * _glowRadiusFactor,
    );

    // The glow is a full circle that fades to nothing at its own edge, so it
    // never shows a hard boundary however the header is resized.
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[AppColors.headerTop, AppColors.headerBottom],
                ),
              ),
            ),
            Positioned.fromRect(
              rect: glow,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.headerGlow,
                      AppColors.headerGlow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // Only this layer rebuilds when the page end is reached; the
            // gradient and the glow under it stay untouched.
            ValueListenableBuilder<bool>(
              valueListenable: atPageEnd,
              builder: (context, atEnd, _) => TweenAnimationBuilder<double>(
                tween: Tween<double>(end: atEnd ? 1 : 0),
                duration: _fade,
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => t == 0
                    ? const SizedBox.shrink()
                    : ColoredBox(
                        color: AppColors.scaffold.withValues(alpha: t),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Darkens the top and bottom of the expanded cover so the status bar icons
/// and the name stay legible over any photo.
///
/// The fade is baked into the gradient's alpha rather than an [Opacity], so
/// it costs no extra compositing layer while the cover opens.
class _CoverScrim extends StatelessWidget {
  const _CoverScrim({required this.opacity});

  final double opacity;

  static const double _topAlpha = 0.35;
  static const double _bottomAlpha = 0.54;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: _topAlpha * opacity),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: _bottomAlpha * opacity),
          ],
          stops: const <double>[0, 0.18, 0.55, 1],
        ),
      ),
    );
  }
}
