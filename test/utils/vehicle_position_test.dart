import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/journey_stop.dart';
import 'package:transportia/utils/vehicle_position.dart';

final DateTime _departure = DateTime.utc(2026, 6, 1, 10);

DateTime _at(Duration offset) => _departure.add(offset);

/// A stop the vehicle arrives at and leaves again. The first and last stops of
/// a trip only have one of the two, as the planner reports them.
JourneyStop _stop({
  required String name,
  DateTime? arrival,
  DateTime? departure,
}) => JourneyStop(
  name: name,
  stopId: name,
  lat: 0,
  lon: 0,
  arrival: arrival,
  departure: departure,
  scheduledArrival: arrival,
  scheduledDeparture: departure,
  track: null,
  scheduledTrack: null,
  cancelled: false,
  alerts: const [],
);

/// Three stops: leaves at 10:00, dwells at the middle from 10:10 to 10:12,
/// arrives at 10:20.
final List<JourneyStop> _trip = [
  _stop(name: 'Origin', departure: _departure),
  _stop(
    name: 'Middle',
    arrival: _at(const Duration(minutes: 10)),
    departure: _at(const Duration(minutes: 12)),
  ),
  _stop(name: 'Terminus', arrival: _at(const Duration(minutes: 20))),
];

void main() {
  group('where the vehicle is', () {
    test('an empty trip says nothing', () {
      final position = estimateVehiclePosition(const [], now: _departure);
      expect(position.isKnown, isFalse);
      expect(position.showsMarker(0), isFalse);
      expect(position.lastServedStopIndex(0), kNoStopIndex);
      expect(position.upcomingStopIndex(0), kNoStopIndex);
    });

    test('before departure it waits at the first stop', () {
      final position = estimateVehiclePosition(
        _trip,
        now: _at(const Duration(minutes: -5)),
      );
      expect(position.isBeforeStart, isTrue);
      expect(position.stopIndex, 0);
      expect(position.isAtStop, isTrue);
      // Nothing has been served yet, so no stop is drawn as passed.
      expect(position.lastServedStopIndex(_trip.length), kNoStopIndex);
      // The stop it is standing at is the one still to come.
      expect(position.upcomingStopIndex(_trip.length), 0);
    });

    test('the departure minute itself counts as departing, not waiting', () {
      // A timetable saying 10:00 and a clock saying 10:00:40 are the same
      // moment to someone on the platform.
      final position = estimateVehiclePosition(
        _trip,
        now: _at(const Duration(seconds: 40)),
      );
      expect(position.isBeforeStart, isFalse);
      expect(position.stopIndex, 0);
      expect(position.isAtStop, isTrue);
      expect(position.lastServedStopIndex(_trip.length), 0);
      expect(position.upcomingStopIndex(_trip.length), 1);
    });

    test('between two stops it sits behind the one it has left', () {
      final position = estimateVehiclePosition(
        _trip,
        now: _at(const Duration(minutes: 5)),
      );
      expect(position.stopIndex, 0);
      expect(position.isAtStop, isFalse);
      expect(position.lastServedStopIndex(_trip.length), 0);
      expect(position.upcomingStopIndex(_trip.length), 1);
      // The marker goes on the line after stop 0, not on a stop.
      expect(position.sitsBetweenStops(0, _trip.length), isTrue);
      expect(position.sitsBetweenStops(1, _trip.length), isFalse);
    });

    test('dwelling at a stop it is on that stop, not the line', () {
      final position = estimateVehiclePosition(
        _trip,
        now: _at(const Duration(minutes: 11)),
      );
      expect(position.stopIndex, 1);
      expect(position.isAtStop, isTrue);
      expect(position.sitsBetweenStops(1, _trip.length), isFalse);
      expect(position.upcomingStopIndex(_trip.length), 2);
    });

    test('after the last arrival it stays at the terminus', () {
      final position = estimateVehiclePosition(
        _trip,
        now: _at(const Duration(hours: 1)),
      );
      expect(position.isAfterEnd, isTrue);
      expect(position.stopIndex, _trip.length - 1);
      // Everything is behind it, and nothing is still to come.
      expect(position.lastServedStopIndex(_trip.length), _trip.length - 1);
      expect(position.upcomingStopIndex(_trip.length), kNoStopIndex);
    });

    test('a trip with no times at all reports the terminus', () {
      // Nothing to reason from, and claiming a position would put the marker
      // somewhere the feed never said it was.
      final untimed = [_stop(name: 'A'), _stop(name: 'B')];
      final position = estimateVehiclePosition(untimed, now: _departure);
      expect(position.isAfterEnd, isTrue);
      expect(position.stopIndex, 1);
    });

    test('a marker only shows for a stop the trip actually has', () {
      const beyond = VehiclePosition(
        stopIndex: 5,
        isAtStop: true,
        isBeforeStart: false,
        isAfterEnd: false,
      );
      expect(beyond.showsMarker(3), isFalse);
      expect(VehiclePosition.unknown.showsMarker(3), isFalse);
    });

    test('the last stop has nothing upcoming after it', () {
      const atLast = VehiclePosition(
        stopIndex: 2,
        isAtStop: true,
        isBeforeStart: false,
        isAfterEnd: false,
      );
      expect(atLast.upcomingStopIndex(3), kNoStopIndex);
    });
  });
}
