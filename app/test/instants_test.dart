import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/time/instants.dart';

void main() {
  test('offset and Z timestamps are the same instant', () {
    final eastern = parseInstant('2026-06-01T08:00:00-04:00');
    final utc = parseInstant('2026-06-01T12:00:00Z');
    expect(eastern.isAtSameMomentAs(utc), isTrue);
    expect(eastern.isAfter(utc), isFalse);
    expect(utc.isAfter(eastern), isFalse);
  });

  test('a later offset is newer even when the calendar date looks older', () {
    final cursor = parseInstant('2026-01-01T00:00:00Z');
    final updated = parseInstant('2025-12-31T20:00:00-05:00');
    expect(updated.isAfter(cursor), isTrue);
    expect(isNewerThanCursor(updated, cursor), isTrue);
    expect(
      '2025-12-31T20:00:00-05:00'.compareTo('2026-01-01T00:00:00Z') < 0,
      isTrue,
    );
  });

  test('a missing offset is rejected', () {
    expect(() => parseInstant('2026-06-01T12:00:00'), throwsFormatException);
  });

  test('an empty cursor treats every instant as newer', () {
    expect(
      isNewerThanCursor(parseInstant('2020-01-01T00:00:00Z'), null),
      isTrue,
    );
  });
}
