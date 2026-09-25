import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/constants/theme/app_colors.dart';
import '../layout/media_images.dart';
import '../layout/profile_metrics.dart';

/// Floating preview of a post with Telegram's context menu under it.
///
/// The page behind is blurred and dimmed rather than replaced, and tapping
/// anywhere outside the card closes the preview. Swiping the card moves
/// between [assets].
///
/// The page is blurred by a single full-screen filter at a fixed sigma, so
/// the blur pass itself never changes; only the dimming animates. The menu
/// has no filter of its own: it sits on that already blurred page, so a
/// second blur would cost a backdrop pass and change nothing on screen.
class StoryPreview extends StatefulWidget {
  const StoryPreview({
    super.key,
    required this.assets,
    required this.animation,
    this.initialIndex = 0,
    this.onMenuSelected,
  });

  final List<String> assets;
  final int initialIndex;
  final Animation<double> animation;

  /// Called with the chosen menu entry after the preview has closed. The
  /// preview is its own route above the page, so the page reports the
  /// result where it is visible.
  final void Function(IconData icon, String label)? onMenuSelected;

  static Future<void> show(
    BuildContext context, {
    required List<String> assets,
    int initialIndex = 0,
    void Function(IconData icon, String label)? onMenuSelected,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, _) => StoryPreview(
          assets: assets,
          initialIndex: initialIndex,
          animation: animation,
          onMenuSelected: onMenuSelected,
        ),
      ),
    );
  }

  @override
  State<StoryPreview> createState() => _StoryPreviewState();
}

class _StoryPreviewState extends State<StoryPreview> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _select(_MenuEntry entry) {
    Navigator.of(context).pop();
    widget.onMenuSelected?.call(entry.icon, entry.label);
  }

  static const double _pageBlurSigma = 20;

  @override
  Widget build(BuildContext context) {
    final metrics = ProfileMetrics.of(context);
    final size = metrics.screen;
    final cardWidth = MediaImages.previewCardWidth(size);
    final cardHeight = (cardWidth * 1.3).clamp(0.0, size.height * 0.52);
    final decodeWidth = MediaImages.decodeWidth(
      metrics,
      MediaQuery.devicePixelRatioOf(context),
    );
    final curved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final menuCurve = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: _pageBlurSigma,
                sigmaY: _pageBlurSigma,
              ),
              child: AnimatedBuilder(
                animation: curved,
                builder: (context, _) => ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35 * curved.value),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FadeTransition(
                      opacity: curved,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.86,
                          end: 1,
                        ).animate(curved),
                        child: _PreviewCard(
                          width: cardWidth,
                          height: cardHeight,
                          assets: widget.assets,
                          decodeWidth: decodeWidth,
                          controller: _pages,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.08),
                        end: Offset.zero,
                      ).animate(menuCurve),
                      child: AnimatedBuilder(
                        animation: menuCurve,
                        builder: (context, _) => _ActionMenu(
                          opacity: menuCurve.value.clamp(0.0, 1.0),
                          onSelected: _select,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The rounded, swipeable page of post images.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.width,
    required this.height,
    required this.assets,
    required this.decodeWidth,
    required this.controller,
  });

  final double width;
  final double height;
  final List<String> assets;
  final int decodeWidth;
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(22)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: PageView.builder(
            controller: controller,
            itemCount: assets.length,
            itemBuilder: (context, index) => Image(
              image: MediaImages.provider(assets[index], decodeWidth),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the [_ActionMenu].
class _MenuEntry {
  const _MenuEntry(this.icon, this.label, {this.destructive = false});

  final IconData icon;
  final String label;
  final bool destructive;
}

/// Context menu shown under the story card.
class _ActionMenu extends StatelessWidget {
  const _ActionMenu({required this.opacity, required this.onSelected});

  /// Folded into every colour instead of an [Opacity] layer.
  final double opacity;
  final ValueChanged<_MenuEntry> onSelected;

  Color _fade(Color color) => color.withValues(alpha: color.a * opacity);

  static const Color _destructive = Color(0xFFE5575F);

  static const _MenuEntry _album = _MenuEntry(
    Icons.create_new_folder_outlined,
    'Add to Album',
  );

  static const List<_MenuEntry> _entries = <_MenuEntry>[
    _MenuEntry(Icons.check_circle_outline_rounded, 'Select'),
    _MenuEntry(Icons.push_pin_outlined, 'Pin'),
    _MenuEntry(Icons.archive_outlined, 'Archive'),
    _MenuEntry(Icons.delete_outline_rounded, 'Delete', destructive: true),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: ColoredBox(
        color: _fade(const Color(0xE6212B35)),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _tile(_album),
              ColoredBox(
                color: _fade(const Color(0xFF18212A)),
                child: const SizedBox(height: 8),
              ),
              for (final entry in _entries) _tile(entry),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(_MenuEntry entry) {
    final color = _fade(
      entry.destructive ? _destructive : AppColors.primaryText,
    );
    return InkWell(
      onTap: () => onSelected(entry),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 13, 34, 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(entry.icon, size: 24, color: color),
            const SizedBox(width: 20),
            Text(
              entry.label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
