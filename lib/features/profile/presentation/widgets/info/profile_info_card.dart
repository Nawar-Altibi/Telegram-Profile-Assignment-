import 'package:flutter/material.dart';

import '../../../../../core/constants/theme/app_colors.dart';
import '../../layout/profile_metrics.dart';
import '../../view_models/profile_view_model.dart';
import 'info_field_tile.dart';

/// The phone / bio / username / birthday card.
///
/// Rows come from [ProfileViewModel.fields] rather than being written out one
/// by one, so adding a field to the repository is enough to make it appear.
class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({super.key, required this.fields});

  final List<ProfileFieldViewModel> fields;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileMetrics.horizontalPadding,
        ProfileMetrics.infoCardTopGap,
        ProfileMetrics.horizontalPadding,
        0,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(ProfileMetrics.infoCardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final field in fields) InfoFieldTile(field: field),
            ],
          ),
        ),
      ),
    );
  }
}
