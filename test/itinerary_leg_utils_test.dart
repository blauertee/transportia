import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/utils/itinerary_leg_utils.dart';

Leg _leg({
  required String mode,
  required String from,
  required String to,
  String? tripId,
  String? fromStopId,
  String? toStopId,
}) {
  final start = DateTime.parse('2026-08-05T07:00:00Z');
  return Leg(
    mode: mode,
    fromName: from,
    toName: to,
    startTime: start,
    endTime: start.add(const Duration(minutes: 10)),
    duration: 600,
    tripId: tripId,
    fromStopId: fromStopId,
    toStopId: toStopId,
    fromLat: 52.5,
    fromLon: 13.4,
    toLat: 52.4,
    toLon: 13.5,
  );
}

/// The shape the planner actually returns for a journey between two
/// coordinates: placeholder edges wrapping the real stops.
List<Leg> _coordinateToCoordinate() => [
  _leg(
    mode: 'WALK',
    from: 'START',
    to: 'S+U Berlin Hauptbahnhof',
    toStopId: 'stop-hbf',
  ),
  _leg(
    mode: 'REGIONAL_RAIL',
    from: 'S+U Berlin Hauptbahnhof',
    to: 'Flughafen BER',
    tripId: 'trip-1',
    fromStopId: 'stop-hbf',
    toStopId: 'stop-ber',
  ),
  _leg(mode: 'WALK', from: 'Flughafen BER', to: 'END', fromStopId: 'stop-ber'),
];

void main() {
  group('isPlaceholderEndpointName', () {
    test('recognises the planner placeholders', () {
      expect(isPlaceholderEndpointName('START'), isTrue);
      expect(isPlaceholderEndpointName('END'), isTrue);
      expect(isPlaceholderEndpointName('start'), isTrue);
      expect(isPlaceholderEndpointName('  END  '), isTrue);
    });

    test('treats missing and blank names as placeholders', () {
      expect(isPlaceholderEndpointName(null), isTrue);
      expect(isPlaceholderEndpointName(''), isTrue);
      expect(isPlaceholderEndpointName('   '), isTrue);
    });

    test('leaves real names alone', () {
      expect(isPlaceholderEndpointName('Flughafen BER'), isFalse);
      expect(isPlaceholderEndpointName('Startbahn West'), isFalse);
      expect(isPlaceholderEndpointName('Ende'), isFalse);
    });
  });

  group('endpoint name resolution', () {
    test('looks past the placeholder edges to the real stops', () {
      final legs = _coordinateToCoordinate();

      expect(resolveOriginName(legs), 'S+U Berlin Hauptbahnhof');
      expect(resolveDestinationName(legs), 'Flughafen BER');
    });

    test('uses the endpoints directly when both are real stops', () {
      final legs = [
        _leg(
          mode: 'REGIONAL_RAIL',
          from: 'Ostkreuz',
          to: 'Flughafen BER',
          tripId: 'trip-1',
        ),
      ];

      expect(resolveOriginName(legs), 'Ostkreuz');
      expect(resolveDestinationName(legs), 'Flughafen BER');
    });

    test('spans transfers to reach the outermost real names', () {
      final legs = [
        _leg(mode: 'WALK', from: 'START', to: 'Alexanderplatz'),
        _leg(
          mode: 'METRO',
          from: 'Alexanderplatz',
          to: 'Hauptbahnhof',
          tripId: 'a',
        ),
        _leg(mode: 'WALK', from: 'Hauptbahnhof', to: 'Hauptbahnhof'),
        _leg(
          mode: 'REGIONAL_RAIL',
          from: 'Hauptbahnhof',
          to: 'Flughafen BER',
          tripId: 'b',
        ),
        _leg(mode: 'WALK', from: 'Flughafen BER', to: 'END'),
      ];

      expect(resolveOriginName(legs), 'Alexanderplatz');
      expect(resolveDestinationName(legs), 'Flughafen BER');
    });

    test('returns null when nothing in the journey is named', () {
      final legs = [_leg(mode: 'WALK', from: 'START', to: 'END')];

      expect(resolveOriginName(legs), isNull);
      expect(resolveDestinationName(legs), isNull);
    });

    test('finds the stop ids for those same endpoints', () {
      final legs = _coordinateToCoordinate();

      expect(resolveOriginStopId(legs), 'stop-hbf');
      expect(resolveDestinationStopId(legs), 'stop-ber');
    });

    test('returns null stop ids when the journey touches no stop', () {
      final legs = [_leg(mode: 'WALK', from: 'START', to: 'END')];

      expect(resolveOriginStopId(legs), isNull);
      expect(resolveDestinationStopId(legs), isNull);
    });

    test('returns null for an empty leg list', () {
      expect(resolveOriginName(const []), isNull);
      expect(resolveDestinationName(const []), isNull);
    });

    test('skips blank names as well as placeholders', () {
      final legs = [
        _leg(mode: 'WALK', from: 'START', to: '   '),
        _leg(mode: 'BUS', from: '', to: 'Rathaus', tripId: 'trip-1'),
        _leg(mode: 'WALK', from: 'Rathaus', to: ''),
      ];

      expect(resolveOriginName(legs), 'Rathaus');
      expect(resolveDestinationName(legs), 'Rathaus');
    });
  });
}
