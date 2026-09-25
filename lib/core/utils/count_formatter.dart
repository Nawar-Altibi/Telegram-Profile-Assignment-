/// Formats view counts the way Telegram does: plain below a thousand, then
/// one decimal with a K/M suffix and no trailing `.0`.
String formatCompactCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) return '${_oneDecimal(value / 1000)}K';
  return '${_oneDecimal(value / 1000000)}M';
}

String _oneDecimal(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// `m:ss` for short clips, `h:mm:ss` beyond an hour.
String formatMediaDuration(Duration duration) {
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60);
  if (duration.inHours == 0) return '$minutes:$seconds';
  return '${duration.inHours}:${minutes.toString().padLeft(2, '0')}:$seconds';
}
