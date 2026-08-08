import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/services/itinerary_refresh_service.dart';

Leg _leg({
  required String mode,
  String? tripId,
  required DateTime startTime,
  required DateTime endTime,
  bool cancelled = false,
  bool realTime = false,
}) {
  return Leg(
    mode: mode,
    fromName: 'A',
    toName: 'B',
    startTime: startTime,
    endTime: endTime,
    duration: endTime.difference(startTime).inSeconds,
    tripId: tripId,
    cancelled: cancelled,
    realTime: realTime,
    fromLat: 52.5,
    fromLon: 13.4,
    toLat: 52.4,
    toLon: 13.5,
  );
}

Itinerary _itinerary(List<Leg> legs) {
  return Itinerary(
    duration: legs.last.endTime.difference(legs.first.startTime).inSeconds,
    startTime: legs.first.startTime,
    endTime: legs.last.endTime,
    transfers: 0,
    legs: legs,
  );
}

final DateTime _depart = DateTime.parse('2026-08-05T07:14:00Z');
final DateTime _arrive = DateTime.parse('2026-08-05T07:29:00Z');

void main() {
  group('ItineraryRefreshService.refresh', () {
    test('reports notRefreshable for a walk-only itinerary', () async {
      final itinerary = _itinerary([
        _leg(mode: 'WALK', startTime: _depart, endTime: _arrive),
      ]);

      final result = await ItineraryRefreshService.refresh(
        itinerary,
        fetchTripDetails: ({required String tripId}) async =>
            fail('should not fetch anything for a walk-only itinerary'),
      );

      expect(result.freshness, ItineraryFreshness.notRefreshable);
      expect(result.didRefresh, isFalse);
      expect(result.itinerary, same(itinerary));
    });

    test('reports scheduled when every lookup fails', () async {
      final itinerary = _itinerary([
        _leg(
          mode: 'RAIL',
          tripId: 'trip-1',
          startTime: _depart,
          endTime: _arrive,
        ),
      ]);

      final result = await ItineraryRefreshService.refresh(
        itinerary,
        fetchTripDetails: ({required String tripId}) async =>
            throw Exception('not in the feed yet'),
      );

      // This is the far-future case: nothing was learned, so the caller must
      // not be told the itinerary was just updated.
      expect(result.freshness, ItineraryFreshness.scheduled);
      expect(result.didRefresh, isFalse);
      expect(result.itinerary, same(itinerary));
    });

    test('reports live and merges fresh times when lookups succeed', () async {
      final itinerary = _itinerary([
        _leg(
          mode: 'RAIL',
          tripId: 'trip-1',
          startTime: _depart,
          endTime: _arrive,
        ),
      ]);

      final delayedDepart = _depart.add(const Duration(minutes: 5));
      final delayedArrive = _arrive.add(const Duration(minutes: 5));

      final result = await ItineraryRefreshService.refresh(
        itinerary,
        fetchTripDetails: ({required String tripId}) async => _itinerary([
          _leg(
            mode: 'RAIL',
            tripId: tripId,
            startTime: delayedDepart,
            endTime: delayedArrive,
            realTime: true,
          ),
        ]),
      );

      expect(result.freshness, ItineraryFreshness.live);
      expect(result.didRefresh, isTrue);
      expect(result.itinerary.startTime, delayedDepart);
      expect(result.itinerary.endTime, delayedArrive);
      expect(result.itinerary.legs.single.realTime, isTrue);
    });

    test('reports changed when a refreshed leg is cancelled', () async {
      final itinerary = _itinerary([
        _leg(
          mode: 'RAIL',
          tripId: 'trip-1',
          startTime: _depart,
          endTime: _arrive,
        ),
      ]);

      final result = await ItineraryRefreshService.refresh(
        itinerary,
        fetchTripDetails: ({required String tripId}) async => _itinerary([
          _leg(
            mode: 'RAIL',
            tripId: tripId,
            startTime: _depart,
            endTime: _arrive,
            cancelled: true,
          ),
        ]),
      );

      expect(result.freshness, ItineraryFreshness.changed);
      // Still counts as a refresh: we did learn the current state.
      expect(result.didRefresh, isTrue);
      expect(result.itinerary.legs.single.cancelled, isTrue);
    });

    test('merges only the legs whose trip resolved', () async {
      final itinerary = _itinerary([
        _leg(
          mode: 'RAIL',
          tripId: 'trip-1',
          startTime: _depart,
          endTime: _arrive,
        ),
        _leg(
          mode: 'BUS',
          tripId: 'trip-2',
          startTime: _arrive,
          endTime: _arrive.add(const Duration(minutes: 10)),
        ),
      ]);

      final result = await ItineraryRefreshService.refresh(
        itinerary,
        fetchTripDetails: ({required String tripId}) async {
          if (tripId == 'trip-2') throw Exception('no data');
          return _itinerary([
            _leg(
              mode: 'RAIL',
              tripId: tripId,
              startTime: _depart,
              endTime: _arrive,
              realTime: true,
            ),
          ]);
        },
      );

      expect(result.freshness, ItineraryFreshness.live);
      expect(result.itinerary.legs.first.realTime, isTrue);
      expect(result.itinerary.legs.last.realTime, isFalse);
    });
  });
}
