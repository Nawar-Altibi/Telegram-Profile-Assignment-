import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports [extent] as the pinned height of [sliver].
///
/// [SliverMainAxisGroup] pins its children correctly but does not add their
/// pinned heights to its own geometry, so a [SliverOverlapAbsorber] around it
/// would absorb nothing and the tab grids would start underneath the pinned
/// header and tab strip.
class PinnedObstruction extends SingleChildRenderObjectWidget {
  const PinnedObstruction({
    super.key,
    required this.extent,
    required Widget sliver,
  }) : super(child: sliver);

  final double extent;

  @override
  RenderPinnedObstruction createRenderObject(BuildContext context) =>
      RenderPinnedObstruction(extent);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPinnedObstruction renderObject,
  ) {
    renderObject.extent = extent;
  }
}

/// Lays the child out unchanged and only overrides its
/// [SliverGeometry.maxScrollObstructionExtent], which is what
/// [SliverOverlapAbsorber] reads.
class RenderPinnedObstruction extends RenderProxySliver {
  RenderPinnedObstruction(this._extent);

  double _extent;
  double get extent => _extent;
  set extent(double value) {
    if (value == _extent) return;
    _extent = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    final SliverGeometry childGeometry = child!.geometry!;
    geometry = childGeometry.copyWith(
      maxScrollObstructionExtent: extent.clamp(0.0, childGeometry.scrollExtent),
    );
  }
}
