import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/api/query.dart';

void main() {
  group('coordinates', () {
    // MOTIS is not self-consistent here: /plan, /geocode and /map/* take
    // "lat,lon" while /one-to-many, /one-to-all and /rentals reject that form
    // with "<value> is not a valid geo coordinate" and want "lat;lon".
    test('comma form is used by plan, geocode and map endpoints', () {
      expect(Q.latLonComma(52.52, 13.405), '52.520000,13.405000');
    });

    test('semicolon form is used by reachability and rentals endpoints', () {
      expect(Q.latLonSemicolon(52.52, 13.405), '52.520000;13.405000');
    });

    test('coordinates keep six decimals and negative signs', () {
      expect(Q.latLonComma(-33.8688, -151.2093), '-33.868800,-151.209300');
    });

    test('coordinates are rounded, not truncated', () {
      expect(Q.latLonComma(1.23456789, 0.0), '1.234568,0.000000');
    });
  });

  group('csv', () {
    test('joins with commas', () {
      expect(Q.csv(['BUS', 'RAIL']), 'BUS,RAIL');
    });

    test('is null for null and empty lists so the param is dropped', () {
      // An empty string is a real value to MOTIS, not an absent one.
      expect(Q.csv(null), isNull);
      expect(Q.csv(const <String>[]), isNull);
    });

    test('csvNum formats numbers without trailing zeros', () {
      expect(Q.csvNum([5, 10.0, 2.5]), '5,10,2.5');
    });
  });

  group('scalars', () {
    test('booleans use lowercase wire form', () {
      expect(Q.boolean(true), 'true');
      expect(Q.boolean(false), 'false');
      expect(Q.boolean(null), isNull);
    });

    test('durations are emitted in whole seconds', () {
      expect(Q.seconds(const Duration(minutes: 15)), '900');
      expect(Q.seconds(null), isNull);
    });

    test('minutes are emitted for the parameters that want minutes', () {
      expect(Q.minutes(const Duration(minutes: 5)), '5');
    });

    test('integral doubles lose the trailing .0', () {
      expect(Q.number(1.0), '1');
      expect(Q.number(1.5), '1.5');
      expect(Q.number(3), '3');
      expect(Q.number(null), isNull);
    });

    test('timestamps are UTC with millisecond precision', () {
      final time = DateTime.utc(2026, 8, 8, 9, 20, 30, 40);
      expect(Q.dateTime(time), '2026-08-08T09:20:30.040Z');
    });

    test('local timestamps are converted to UTC', () {
      final local = DateTime.utc(2026, 8, 8, 9).toLocal();
      expect(Q.dateTime(local), '2026-08-08T09:00:00.000Z');
    });
  });
}
