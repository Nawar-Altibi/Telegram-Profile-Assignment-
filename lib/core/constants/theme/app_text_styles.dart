import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Text styles shared by the profile screen.
///
/// The header title is deliberately declared once at its largest size
/// ([headerNameBase]) and scaled with a transform while the header morphs, so
/// the paragraph is laid out and shaped a single time instead of once per
/// scrolled frame.
abstract final class AppTextStyles {
  const AppTextStyles._();

  static const TextStyle headerNameBase = TextStyle(
    color: AppColors.primaryText,
    fontSize: 24,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle headerStatusBase = TextStyle(
    color: Color(0xFFCBD5DC),
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle actionLabel = TextStyle(
    color: AppColors.primaryText,
    fontSize: 12,
    height: 1.1,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle fieldValue = TextStyle(
    color: AppColors.primaryText,
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle fieldLabel = TextStyle(
    color: AppColors.secondaryText,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle tabLabel = TextStyle(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle mediaBadge = TextStyle(
    color: AppColors.primaryText,
    fontSize: 12,
    height: 1.1,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle navLabel = TextStyle(
    fontSize: 11,
    height: 1.1,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle emptyTitle = TextStyle(
    color: AppColors.primaryText,
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle emptyBody = TextStyle(
    color: AppColors.secondaryText,
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );
}
