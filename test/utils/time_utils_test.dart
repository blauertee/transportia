import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/time_utils.dart';

void main() {
  group('two moments in the same minute', () {
    test('seconds within one minute do not separate them', () {
      // The whole point: a timetable prints minutes, so anything finer than a
      // minute is noise when comparing a clock against one.
      expect(
        isSameMinute(
          DateTime.utc(2026, 6, 1, 10, 3),
          DateTime.utc(2026, 6, 1, 10, 3, 59),
        ),
        isTrue,
      );
    });

    test('a second past the minute is the next minute', () {
      expect(
        isSameMinute(
          DateTime.utc(2026, 6, 1, 10, 3, 59),
          DateTime.utc(2026, 6, 1, 10, 4),
        ),
        isFalse,
      );
    });

    test('the same wall clock on different days is not the same minute', () {
      expect(
        isSameMinute(
          DateTime.utc(2026, 6, 1, 10, 3),
          DateTime.utc(2026, 6, 2, 10, 3),
        ),
        isFalse,
      );
    });

    test('compares local time, so a UTC and a local reading agree', () {
      final utc = DateTime.utc(2026, 6, 1, 10, 3);
      expect(isSameMinute(utc, utc.toLocal()), isTrue);
    });
  });
}
