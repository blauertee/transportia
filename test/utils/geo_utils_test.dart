import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/geo_utils.dart';

void main() {
  group('coordKey', () {
    test('defaults to six decimals on both halves', () {
      expect(coordKey(52.5, 13.4), '52.500000,13.400000');
    });

    test('honours a coarser precision', () {
      expect(coordKey(52.51234, 13.42891, decimals: 1), '52.5,13.4');
    });

    test('rounds rather than truncates', () {
      expect(coordKey(52.58, 13.42, decimals: 1), '52.6,13.4');
    });

    test('keeps the sign of a negative coordinate', () {
      expect(coordKey(-33.8688, -151.2093, decimals: 4), '-33.8688,-151.2093');
    });

    test('a coordinate on the meridian keeps its zeroes', () {
      expect(coordKey(0, 0, decimals: 2), '0.00,0.00');
    });

    test('takes another separator, for keys that need one', () {
      expect(coordKey(52.5, 13.4, decimals: 1, separator: '|'), '52.5|13.4');
    });

    test('never emits a space, so it stays safe in a key or a URL', () {
      for (final decimals in [0, 1, 4, 6]) {
        expect(coordKey(-52.5, 13.4, decimals: decimals), isNot(contains(' ')));
      }
    });

    test('two coordinates closer than the precision share a key', () {
      // What the fuzzy buckets rely on: near-identical results collapse.
      expect(
        coordKey(52.5001, 13.4001, decimals: 1),
        coordKey(52.5, 13.4, decimals: 1),
      );
    });
  });

  group('coordLabel', () {
    test('defaults to four decimals, comma and space', () {
      expect(coordLabel(52.51234, 13.42891), '52.5123, 13.4289');
    });

    test('honours a finer precision', () {
      expect(coordLabel(52.5, 13.4, decimals: 6), '52.500000, 13.400000');
    });

    test('keeps the sign of a negative coordinate', () {
      expect(coordLabel(-33.8688, -151.2093), '-33.8688, -151.2093');
    });
  });
}
