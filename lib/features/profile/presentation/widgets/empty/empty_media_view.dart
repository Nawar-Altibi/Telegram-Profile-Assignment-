import 'package:flutter/material.dart';

import '../../../../../core/constants/theme/app_text_styles.dart';

/// Shown when a tab has no media, matching Telegram's own wording.
class EmptyMediaView extends StatelessWidget {
  const EmptyMediaView({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: AppTextStyles.emptyTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: AppTextStyles.emptyBody,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The note Telegram prints above archived stories.
class ArchivedNotice extends StatelessWidget {
  const ArchivedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Text(
        'Only you can see archived stories unless you choose to post them '
        'to your profile.',
        style: AppTextStyles.emptyBody,
        textAlign: TextAlign.center,
      ),
    );
  }
}
