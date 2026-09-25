import 'package:flutter/material.dart';

import '../../layout/media_images.dart';
import '../../layout/profile_metrics.dart';
import '../../view_models/media_item_view_model.dart';
import 'media_tile.dart';

/// Lazily built two-column media grid.
///
/// [SliverGrid.builder] keeps construction proportional to what is on screen,
/// so the same widget handles fourteen posts or fourteen thousand. Only the
/// four corners of the whole block are rounded, which is computed per index
/// rather than by special-casing widgets, so it survives any item count.
class MediaGridSliver extends StatelessWidget {
  const MediaGridSliver({
    super.key,
    required this.items,
    required this.metrics,
    this.onItemTap,
  });

  final List<MediaItemViewModel> items;
  final ProfileMetrics metrics;
  final ValueChanged<int>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final columns = metrics.gridColumnCount;
    final radius = const Radius.circular(ProfileMetrics.gridCornerRadius);
    final rowCount = (items.length / columns).ceil();
    final decodeWidth = MediaImages.decodeWidth(
      metrics,
      MediaQuery.devicePixelRatioOf(context),
    );

    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileMetrics.gridMargin,
      ),
      // The builder delegate wraps every tile in its own RepaintBoundary, so
      // the grid repaints only the tiles entering or leaving the viewport.
      sliver: SliverGrid.builder(
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: ProfileMetrics.gridSpacing,
          crossAxisSpacing: ProfileMetrics.gridSpacing,
          childAspectRatio: ProfileMetrics.gridTileAspectRatio,
        ),
        itemBuilder: (context, index) {
          final row = index ~/ columns;
          final column = index % columns;
          final isLastRow = row == rowCount - 1;
          return MediaTile(
            key: ValueKey<String>(items[index].id),
            item: items[index],
            decodeWidth: decodeWidth,
            onTap: onItemTap == null ? null : () => onItemTap!(index),
            borderRadius: BorderRadius.only(
              topLeft: row == 0 && column == 0 ? radius : Radius.zero,
              topRight: row == 0 && column == columns - 1
                  ? radius
                  : Radius.zero,
              bottomLeft: isLastRow && column == 0 ? radius : Radius.zero,
              bottomRight: isLastRow && column == columns - 1
                  ? radius
                  : Radius.zero,
            ),
          );
        },
      ),
    );
  }
}
