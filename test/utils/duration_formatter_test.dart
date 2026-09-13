import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/duration_formatter.dart';

void main() {
  group('formatDistanceKm', () {
    test('a distance of nothing still reads as a distance', () {
      expect(formatDistanceKm(0), '0.00 km');
    });

    test('a sub-kilometre walk keeps its leading zero', () {
      expect(formatDistanceKm(450), '0.45 km');
    });

    test('an exact kilometre keeps both decimals', () {
      expect(formatDistanceKm(1000), '1.00 km');
    });

    test('one decimal is available for chips', () {
      expect(formatDistanceKm(1234, decimals: 1), '1.2 km');
    });

    test('rounds rather than truncates', () {
      expect(formatDistanceKm(1999), '2.00 km');
    });
  });

  group('formatDuration', () {
    test('under an hour reads in minutes alone', () {
      expect(formatDuration(600), '10m');
    });

    test('over an hour reads in both', () {
      expect(formatDuration(3900), '1h 5m');
    });

    test('a negative duration is refused rather than shown as a time', () {
      expect(formatDuration(-1), 'N/A');
    });
  });
}
