import 'package:flutter/widgets.dart';

/// The thin segmented bar Telegram draws over an expanded cover, one segment
/// per unseen story.
class StorySegments extends StatelessWidget {
  const StorySegments({super.key, required this.count, this.activeIndex = 0});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Gaps never take more than a quarter of the bar, so a large story
          // count thins the gaps instead of overflowing.
          final double gap = count <= 1
              ? 0
              : (constraints.maxWidth * 0.25 / (count - 1)).clamp(0.0, 4.0);
          return Row(
            children: <Widget>[
              for (var i = 0; i < count; i++) ...<Widget>[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFFFFFFF,
                      ).withValues(alpha: i == activeIndex ? 0.95 : 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
