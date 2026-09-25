import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/theme/app_colors.dart';
import 'frosted_surface.dart';

/// Content of one [FloatingNotice]. Every call to show a notice creates a new
/// instance, so repeating the same action still restarts it.
@immutable
class AppNotice {
  const AppNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;
}

/// Holds the notice currently on screen and hides it after a delay.
///
/// Anything below a [NoticeScope] reaches it through [NoticeScope.of] and
/// calls [show]; the [FloatingNotice] listening to it does the animating.
class NoticeController extends ValueNotifier<AppNotice?> {
  NoticeController() : super(null);

  static const Duration defaultDuration = Duration(milliseconds: 1800);

  Timer? _timer;

  void show({
    required IconData icon,
    required String title,
    required String message,
    Duration duration = defaultDuration,
  }) {
    value = AppNotice(icon: icon, title: title, message: message);
    _timer?.cancel();
    _timer = Timer(duration, hide);
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    value = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Makes a [NoticeController] available to the widgets below it.
class NoticeScope extends InheritedWidget {
  const NoticeScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final NoticeController controller;

  /// The nearest controller. Looked up without registering a dependency:
  /// callers only use it from event handlers, never while building.
  static NoticeController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NoticeScope>()?.controller;

  static NoticeController of(BuildContext context) {
    final NoticeController? controller = maybeOf(context);
    assert(controller != null, 'No NoticeScope above this context.');
    return controller!;
  }

  @override
  bool updateShouldNotify(NoticeScope oldWidget) =>
      oldWidget.controller != controller;
}

/// Short-lived frosted card that floats above the bottom controls.
///
/// It replaces the stock [SnackBar], whose light Material surface clashed
/// with the dark translucent bar and covered it. The card uses the same
/// [FrostedSurface] as the bar so the content behind blurs through it.
///
/// Showing and hiding is driven entirely by [notice]: a value animates the
/// card in, `null` animates it out.
class FloatingNotice extends StatefulWidget {
  const FloatingNotice({super.key, required this.notice, this.spacing = 10});

  final ValueListenable<AppNotice?> notice;

  /// Gap kept below the card while it is visible. Collapses with the card so
  /// nothing under it moves when no notice is shown.
  final double spacing;

  @override
  State<FloatingNotice> createState() => _FloatingNoticeState();
}

class _FloatingNoticeState extends State<FloatingNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// Last shown content. Kept while the card animates out, after [notice]
  /// has already gone back to `null`.
  AppNotice? _content;

  @override
  void initState() {
    super.initState();
    // A hide that starts before the value has moved ends as a status change
    // alone, which the AnimatedBuilder below does not hear about.
    _controller.addStatusListener(_onStatus);
    widget.notice.addListener(_sync);
    _sync();
  }

  void _onStatus(AnimationStatus status) {
    if (status.isDismissed && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(FloatingNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice != widget.notice) {
      oldWidget.notice.removeListener(_sync);
      widget.notice.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.notice.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    final AppNotice? next = widget.notice.value;
    if (next == null) {
      _controller.reverse();
      return;
    }
    setState(() => _content = next);
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final AppNotice? content = _content;
        if (content == null || _controller.isDismissed) {
          return const SizedBox.shrink();
        }
        final double t = _progress.value;
        return IgnorePointer(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.spacing),
            // Rises and grows slightly into place. Fading goes through the
            // card's own opacity: an Opacity layer would blind its blur.
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - t)),
              child: Transform.scale(
                scale: 0.94 + 0.06 * t,
                child: Semantics(
                  liveRegion: true,
                  child: _NoticeCard(notice: content, opacity: t),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Icon badge plus title and message on a frosted rounded card.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.opacity});

  final AppNotice notice;
  final double opacity;

  static const double _badgeSize = 34;

  @override
  Widget build(BuildContext context) {
    final double o = opacity.clamp(0.0, 1.0);
    return FrostedSurface(
      borderRadius: BorderRadius.circular(18),
      blurSigma: 24,
      tint: const Color(0xD91A242E),
      borderColor: Colors.white.withValues(alpha: 0.08),
      opacity: o,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 18, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.18 * o),
              ),
              child: SizedBox.square(
                dimension: _badgeSize,
                child: Icon(
                  notice.icon,
                  size: 18,
                  color: AppColors.accentSoft.withValues(alpha: o),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primaryText.withValues(alpha: o),
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notice.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.secondaryText.withValues(alpha: o),
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
