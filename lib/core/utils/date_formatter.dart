const List<String> _monthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `Apr 01, 2004 (22 years old)`.
///
/// The age is derived rather than stored so the card never goes stale.
String formatBirthdayWithAge(DateTime birthday, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final month = _monthAbbreviations[birthday.month - 1];
  final day = birthday.day.toString().padLeft(2, '0');
  final age = _yearsBetween(birthday, today);
  return '$month $day, ${birthday.year} ($age years old)';
}

int _yearsBetween(DateTime birthday, DateTime today) {
  var age = today.year - birthday.year;
  final hadBirthdayThisYear =
      today.month > birthday.month ||
      (today.month == birthday.month && today.day >= birthday.day);
  if (!hadBirthdayThisYear) age--;
  return age;
}
