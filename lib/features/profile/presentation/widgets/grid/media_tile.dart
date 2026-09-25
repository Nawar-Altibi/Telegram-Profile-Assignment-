import 'package:flutter/material.dart';

import '../../../../../core/constants/theme/app_colors.dart';
import '../../layout/media_images.dart';
import '../../view_models/media_item_view_model.dart';
import 'media_badges.dart';

/// A single post thumbnail with its overlays.
///
/// No [RepaintBoundary] here: [SliverGrid]'s builder delegate already gives
/// every tile its own, and a second one would only add a layer.
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.borderRadius,
    required this.decodeWidth,
    this.onTap,
  });

  final MediaItemViewModel item;
  final BorderRadius borderRadius;

  /// Physical pixel width the image is decoded at; see [MediaImages].
  final int decodeWidth;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget content = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: AppColors.mediaPlaceholder),
        Image(
          image: MediaImages.provider(item.assetPath, decodeWidth),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: child,
            );
          },
        ),
        const _BottomScrim(),
        if (item.isPinned)
          const Positioned(
            top: 6,
            right: 6,
            child: Icon(
              Icons.push_pin_rounded,
              size: 16,
              color: Colors.white,
              shadows: <Shadow>[Shadow(blurRadius: 4)],
            ),
          ),
        if (item.durationLabel != null)
          Positioned(
            left: 6,
            bottom: 6,
            child: MediaBadge(
              icon: Icons.play_arrow_rounded,
              label: item.durationLabel!,
            ),
          ),
        Positioned(
          right: 6,
          bottom: 6,
          child: MediaBadge(
            icon: Icons.remove_red_eye_rounded,
            label: item.viewCountLabel,
          ),
        ),
      ],
    );
    // Only the grid's corner tiles are rounded; the rest skip the clip.
    if (borderRadius != BorderRadius.zero) {
      content = ClipRRect(borderRadius: borderRadius, child: content);
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

/// Dark gradient along the bottom edge that keeps the white badges readable
/// on bright photos.
class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[Color(0x66000000), Color(0x00000000)],
          stops: <double>[0, 0.34],
        ),
      ),
    );
  }
}
