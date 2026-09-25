import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/constants/theme/app_colors.dart';
import '../../../../../core/constants/theme/app_text_styles.dart';
import '../../../../../core/helpers/phase.dart';
import '../../../enums/profile_tab.dart';
import '../../layout/profile_metrics.dart';

/// Posts / Archived Posts selector.
///
/// The control hugs its labels and sits centred, the way the reference shows
/// it, instead of stretching across the screen. Each segment is as wide as
/// its own label, so the highlight grows and shrinks as it slides. It is
/// positioned from [TabController.animation] every frame, so it travels with
/// the finger instead of fading in after the page settles.
class SegmentedTabs extends StatefulWidget {
  const SegmentedTabs({super.key, required this.controller});

  final TabController controller;

  @override
  State<SegmentedTabs> createState() => _SegmentedTabsState();
}

class _SegmentedTabsState extends State<SegmentedTabs> {
  /// The labels and their style are constant, so the measured widths only
  /// change with the text scale.
  TextScaler? _cachedScaler;
  List<double>? _cachedWidths;

  List<double> _segmentWidths(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final List<double>? cached = _cachedWidths;
    if (cached != null && _cachedScaler == scaler) return cached;
    final List<double> widths = List<double>.unmodifiable(<double>[
      for (final ProfileTab tab in ProfileTab.values)
        _labelWidth(tab.label, scaler) + ProfileMetrics.tabsLabelPadding * 2,
    ]);
    _cachedScaler = scaler;
    _cachedWidths = widths;
    return widths;
  }

  static double _labelWidth(String label, TextScaler scaler) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: AppTextStyles.tabLabel),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: ProfileMetrics.tabsMaxTextScale,
      child: Builder(
        builder: (context) {
          final List<double> natural = _segmentWidths(context);
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ProfileMetrics.tabsHorizontalPadding,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double naturalTotal = natural.fold(0.0, (a, b) => a + b);
                final double available =
                    constraints.maxWidth - ProfileMetrics.tabsTrackInset * 2;
                final double fit = naturalTotal <= available
                    ? 1
                    : available / naturalTotal;
                final List<double> widths = <double>[
                  for (final double width in natural) width * fit,
                ];
                return Center(
                  child: _Track(
                    controller: widget.controller,
                    widths: widths,
                    height: ProfileMetrics.tabsTrackHeight,
                    inset: ProfileMetrics.tabsTrackInset,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// The rounded track and the selection pill that slides and resizes between
/// segments as the tab animation moves.
class _Track extends StatelessWidget {
  const _Track({
    required this.controller,
    required this.widths,
    required this.height,
    required this.inset,
  });

  final TabController controller;
  final List<double> widths;
  final double height;
  final double inset;

  /// Left edge of each segment inside the track.
  List<double> get _offsets {
    final List<double> offsets = <double>[];
    double left = 0;
    for (final double width in widths) {
      offsets.add(left);
      left += width;
    }
    return offsets;
  }

  @override
  Widget build(BuildContext context) {
    final int count = widths.length;
    final List<double> offsets = _offsets;
    final double total = widths.fold(0.0, (a, b) => a + b);

    return SizedBox(
      width: total + inset * 2,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.tabTrack,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: AnimatedBuilder(
            animation: controller.animation!,
            builder: (context, _) {
              final double page = controller.animation!.value.clamp(
                0.0,
                count - 1.0,
              );
              final int from = page.floor();
              final int to = math.min(from + 1, count - 1);
              final double t = page - from;
              return Stack(
                children: <Widget>[
                  PositionedDirectional(
                    start: lerp(offsets[from], offsets[to], t),
                    width: lerp(widths[from], widths[to], t),
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.tabSelected,
                        borderRadius: BorderRadius.circular(height / 2 - inset),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      for (var i = 0; i < count; i++)
                        SizedBox(
                          width: widths[i],
                          child: _SegmentLabel(
                            tab: ProfileTab.values[i],
                            selection: (1 - (page - i).abs()).clamp(0.0, 1.0),
                            onTap: () => controller.animateTo(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One tappable segment title; [selection] (0 to 1) blends its colour.
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.tab,
    required this.selection,
    required this.onTap,
  });

  final ProfileTab tab;
  final double selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Text(
          tab.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.tabLabel.copyWith(
            color: Color.lerp(
              AppColors.secondaryText,
              AppColors.accentSoft,
              selection,
            ),
          ),
        ),
      ),
    );
  }
}
