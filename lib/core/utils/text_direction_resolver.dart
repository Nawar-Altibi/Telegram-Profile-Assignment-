import 'dart:ui' show TextDirection;

/// Picks a paragraph direction from the first strong directional character,
/// which is the rule Unicode itself uses (UAX #9, "first strong").
///
/// The profile bio is Arabic while every other field is Latin, so resolving
/// per field is what makes the card align each line the way Telegram does
/// instead of forcing the whole screen into one direction.
TextDirection resolveTextDirection(
  String text, {
  TextDirection fallback = TextDirection.ltr,
}) {
  for (final rune in text.runes) {
    if (_isStrongRtl(rune)) return TextDirection.rtl;
    if (_isStrongLtr(rune)) return TextDirection.ltr;
  }
  return fallback;
}

bool _isStrongRtl(int rune) =>
    (rune >= 0x0590 && rune <= 0x08FF) || // Hebrew, Arabic, Syriac, Thaana
    (rune >= 0xFB1D && rune <= 0xFDFF) || // Presentation forms A
    (rune >= 0xFE70 && rune <= 0xFEFF); // Presentation forms B

bool _isStrongLtr(int rune) =>
    (rune >= 0x0041 && rune <= 0x005A) ||
    (rune >= 0x0061 && rune <= 0x007A) ||
    (rune >= 0x00C0 && rune <= 0x02AF);
