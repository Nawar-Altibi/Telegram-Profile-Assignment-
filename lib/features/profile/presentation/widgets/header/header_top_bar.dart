import 'package:flutter/material.dart';

import '../../../../../core/constants/theme/app_colors.dart';
import '../../layout/profile_metrics.dart';

/// The leading and trailing app bar icons.
///
/// They sit above every other header layer and never move, so the widget is
/// built once per header configuration and reused across scrolled frames.
class HeaderTopBar extends StatelessWidget {
  const HeaderTopBar({super.key, required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(top: topInset, start: 4, end: 4),
      child: SizedBox(
        height: ProfileMetrics.toolbarHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const <Widget>[
            _TopBarButton(icon: Icons.qr_code_2_rounded, tooltip: 'QR code'),
            _TopBarButton(icon: Icons.more_vert_rounded, tooltip: 'More'),
          ],
        ),
      ),
    );
  }
}

/// Icon button of the top bar; it has no destination in this assignment.
class _TopBarButton extends StatelessWidget {
  const _TopBarButton({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {},
      tooltip: tooltip,
      icon: Icon(icon, size: 24, color: AppColors.primaryText),
      style: IconButton.styleFrom(
        shadowColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}
