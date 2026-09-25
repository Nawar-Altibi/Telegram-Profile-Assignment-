import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/constants/theme/app_text_styles.dart';
import '../../../../../core/widgets/floating_notice.dart';
import '../../view_models/profile_view_model.dart';

/// One value/label pair inside the information card. A long press copies the
/// value when the field allows it.
///
/// The value carries its own [TextDirection] so an Arabic bio is shaped and
/// ordered right to left while the Latin rows around it stay left to right.
/// Alignment stays on the card's leading edge for every row, which is what
/// the reference does: mixing alignments inside one card looks like a bug.
class InfoFieldTile extends StatelessWidget {
  const InfoFieldTile({super.key, required this.field});

  final ProfileFieldViewModel field;

  @override
  Widget build(BuildContext context) {
    // `TextAlign.start` would resolve against the field's own direction and
    // push the Arabic bio to the far edge, so the card's direction decides
    // alignment while the field's direction decides ordering.
    final align = Directionality.of(context) == TextDirection.rtl
        ? TextAlign.right
        : TextAlign.left;

    return InkWell(
      onLongPress: field.isCopyable ? () => _copy(context) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              field.value,
              style: AppTextStyles.fieldValue,
              textDirection: field.valueDirection,
              textAlign: align,
              softWrap: true,
            ),
            const SizedBox(height: 2),
            Text(field.label, style: AppTextStyles.fieldLabel),
          ],
        ),
      ),
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: field.value));
    HapticFeedback.lightImpact();
    NoticeScope.maybeOf(context)?.show(
      icon: Icons.check_rounded,
      title: '${field.label} copied',
      message: 'Copied to clipboard',
    );
  }
}
