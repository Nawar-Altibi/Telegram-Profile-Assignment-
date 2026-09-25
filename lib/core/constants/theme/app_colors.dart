import 'package:flutter/painting.dart';

/// Static palette of the dark Telegram theme used across the app.
abstract final class AppColors {
  const AppColors._();

  static const Color scaffold = Color(0xFF0E1621);
  static const Color surface = Color(0xFF17212B);

  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFF8A9AA5);

  static const Color accent = Color(0xFF3EAEE8);
  static const Color accentSoft = Color(0xFF55AEDB);
  static const Color tabTrack = Color(0xFF17222A);
  static const Color tabSelected = Color(0xFF1B3B4A);

  static const Color badge = Color(0xFF3EAEE8);

  /// Ring around the unread badge, cutting it out of the navigation bar.
  static const Color badgeBorder = Color(0xFF16202A);

  /// Shown behind a media tile until its image has decoded.
  static const Color mediaPlaceholder = Color(0xFF1B242D);

  /// Profile header gradient behind the resting avatar.
  static const Color headerTop = Color(0xFF3D6C97);
  static const Color headerBottom = Color(0xFF2A5074);

  /// Soft light radiating from behind the resting avatar.
  static const Color headerGlow = Color(0xFF6FA3D2);

  /// Darkening over the top and bottom of the open cover photo, at full
  /// strength; the header scales their alpha as the cover opens.
  static const Color coverScrimTop = Color(0x59000000);
  static const Color coverScrimBottom = Color(0x8A000000);
  static const Color coverScrimClear = Color(0x00000000);

  /// Status and navigation bars; the app draws edge to edge behind them.
  static const Color systemBars = Color(0x00000000);

  /// Icons and their shadows drawn over media thumbnails.
  static const Color mediaOverlayIcon = Color(0xFFFFFFFF);
  static const Color mediaOverlayShadow = Color(0xFF000000);

  /// Translucent pill behind the view count and clip duration.
  static const Color mediaBadge = Color(0x52000000);

  /// Gradient along a media tile's bottom edge that keeps its badges legible.
  static const Color mediaScrim = Color(0x66000000);
  static const Color mediaScrimClear = Color(0x00000000);
}
