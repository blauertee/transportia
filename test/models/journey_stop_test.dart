import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/journey_stop.dart';

final DateTime _arrival = DateTime.utc(2026, 6, 1, 10);
final DateTime _departure = DateTime.utc(2026, 6, 1, 10, 2);

JourneyStop _stop({DateTime? arrival, DateTime? departure}) => JourneyStop(
  name: 'Ostkreuz',
  stopId: 'de-DELFI_stop:42',
  lat: 52.5,
  lon: 13.4,
  arrival: arrival,
  departure: departure,
  scheduledArrival: arrival,
  scheduledDeparture: departure,
  track: null,
  scheduledTrack: null,
  cancelled: false,
  alerts: const [],
);

void main() {
  group('timeAtStop', () {
    test('a stop that is dwelt at reports when the vehicle leaves', () {
      expect(
        _stop(arrival: _arrival, departure: _departure).timeAtStop,
        _departure,
      );
    });

    test('the origin, which is only ever left, reports its departure', () {
      expect(_stop(departure: _departure).timeAtStop, _departure);
    });

    test('the terminus, which is never left, falls back to its arrival', () {
      expect(_stop(arrival: _arrival).timeAtStop, _arrival);
    });

    test('a stop the feed timed neither end of reports nothing', () {
      expect(_stop().timeAtStop, isNull);
    });
  });

  group('timeAtTerminus', () {
    test('prefers the arrival, which is the moment that matters there', () {
      expect(
        _stop(arrival: _arrival, departure: _departure).timeAtTerminus,
        _arrival,
      );
    });

    test('falls back to a departure when the feed gives only one', () {
      expect(_stop(departure: _departure).timeAtTerminus, _departure);
    });

    test('a stop the feed timed neither end of reports nothing', () {
      expect(_stop().timeAtTerminus, isNull);
    });

    test('it disagrees with timeAtStop exactly when both times exist', () {
      final dwelt = _stop(arrival: _arrival, departure: _departure);
      expect(dwelt.timeAtTerminus, isNot(dwelt.timeAtStop));

      final oneEnded = _stop(arrival: _arrival);
      expect(oneEnded.timeAtTerminus, oneEnded.timeAtStop);
    });
  });
}
