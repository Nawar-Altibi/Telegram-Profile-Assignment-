import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/theme/app_text_styles.dart';

/// Display name, laid out once at its largest size.
///
/// The header scales this widget with a transform rather than animating
/// `fontSize`, so the paragraph is measured and shaped a single time instead
/// of on every scrolled frame.
class HeaderNameRow extends StatelessWidget {
  const HeaderNameRow({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: AppTextStyles.headerNameBase,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Status line under the name.
///
/// Shows the presence text, and swaps to the story count only while the page
/// is scrolled to its very end. [showStories] is owned by the screen so the
/// swap never rebuilds the header delegate.
class HeaderStatusText extends StatelessWidget {
  const HeaderStatusText({
    super.key,
    required this.status,
    required this.stories,
    required this.showStories,
  });

  final String status;
  final String stories;
  final ValueListenable<bool> showStories;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: showStories,
      builder: (context, atEnd, _) {
        final String text = atEnd ? stories : status;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            alignment: AlignmentDirectional.centerStart,
            children: <Widget>[...previous, ?current],
          ),
          child: Text(
            text,
            key: ValueKey<String>(text),
            style: AppTextStyles.headerStatusBase,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
