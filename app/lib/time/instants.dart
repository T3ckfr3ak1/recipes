final _offset = RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$', caseSensitive: false);

/// Parses an ISO 8601 timestamp that includes a UTC offset.
///
/// Comparison of the returned values is instant comparison. A value written
/// as `-05:00` and the same moment written as `Z` compare equal.
DateTime parseInstant(String raw, {String field = 'timestamp'}) {
  final value = raw.trim();
  if (!_offset.hasMatch(value)) {
    throw FormatException('$field must be an ISO 8601 time with a UTC offset');
  }
  try {
    return DateTime.parse(value);
  } on FormatException {
    throw FormatException('$field must be an ISO 8601 time with a UTC offset');
  }
}

/// ISO 8601 with a numeric UTC offset, which is the form the repo stores.
String isoWithOffset(DateTime time) {
  final offset = time.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)}'
      'T${two(time.hour)}:${two(time.minute)}:${two(time.second)}'
      '$sign$hours:$minutes';
}

/// True when [updatedAt] is strictly later than [cursor].
///
/// A null cursor means nothing has been pulled yet, so every recipe is due.
bool isNewerThanCursor(DateTime updatedAt, DateTime? cursor) {
  if (cursor == null) return true;
  return updatedAt.isAfter(cursor);
}
