/// Fixed animation durations shared across the app.
abstract final class AppDurations {
  const AppDurations._();

  /// Add-post button sliding in once the posts scroll into view.
  static const Duration addPostSlide = Duration(milliseconds: 220);

  /// Add-post button fading in alongside its slide.
  static const Duration addPostFade = Duration(milliseconds: 180);

  /// A media thumbnail fading in once its image has decoded.
  static const Duration mediaFadeIn = Duration(milliseconds: 180);

  /// Header blue fading into the page colour at the end of the page.
  static const Duration headerPageEndFade = Duration(milliseconds: 260);
}
