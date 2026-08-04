import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/saved_trip.dart';
import 'package:transportia/models/time_selection.dart';
import 'package:transportia/services/saved_trips_service.dart';

/// Builds a `/plan`-shaped itinerary JSON for a single rail leg.
Map<String, dynamic> _planJson({
  required String tripId,
  required DateTime departure,
  Duration length = const Duration(minutes: 15),
}) {
  final arrival = departure.add(length);
  return jsonDecode(
        jsonEncode({
          'duration': length.inSeconds,
          'startTime': departure.toUtc().toIso8601String(),
          'endTime': arrival.toUtc().toIso8601String(),
          'transfers': 0,
          'legs': [
            {
              'mode': 'RAIL',
              'startTime': departure.toUtc().toIso8601String(),
              'endTime': arrival.toUtc().toIso8601String(),
              'duration': length.inSeconds,
              'tripId': tripId,
              'routeShortName': 'RE7',
              'from': {
                'name': 'Hauptbahnhof',
                'lat': 52.525,
                'lon': 13.369,
                'stopId': 'stop-from',
              },
              'to': {
                'name': 'Airport',
                'lat': 52.366,
                'lon': 13.503,
                'stopId': 'stop-to',
              },
            },
          ],
        }),
      )
      as Map<String, dynamic>;
}

SavedTrip _savedTrip({
  String tripId = 'trip-re7',
  required DateTime departure,
  String? label,
}) {
  return SavedTrip.fromItinerary(
    itinerary: Itinerary.fromJson(
      _planJson(tripId: tripId, departure: departure),
    ),
    fromName: 'Hauptbahnhof',
    fromLat: 52.525,
    fromLon: 13.369,
    toName: 'Airport',
    toLat: 52.366,
    toLon: 13.503,
    timeSelection: TimeSelection(dateTime: departure, isArriveBy: false),
    label: label,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SavedTripsService.savedTripsListenable.value = const [];
  });

  final future = DateTime.now().add(const Duration(days: 2));

  group('SavedTrip', () {
    test('round-trips through JSON', () {
      final original = _savedTrip(departure: future, label: 'Airport run');

      final restored = SavedTrip.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, original.id);
      expect(restored.label, 'Airport run');
      expect(restored.fromName, 'Hauptbahnhof');
      expect(restored.toName, 'Airport');
      expect(restored.fromStopId, 'stop-from');
      expect(restored.toStopId, 'stop-to');
      expect(restored.departureTime, original.departureTime);
      expect(restored.arrivalTime, original.arrivalTime);
      expect(restored.timeSelection.dateTime, original.timeSelection.dateTime);
      // The snapshot survives and still parses into the same connection.
      expect(restored.itinerary.legs.single.tripId, 'trip-re7');
      expect(restored.itinerary.startTime, original.itinerary.startTime);
    });

    test('falls back to a generated label, and prefers a user one', () {
      final generated = _savedTrip(departure: future);
      expect(generated.displayLabel, contains('Hauptbahnhof → Airport'));

      final named = _savedTrip(departure: future, label: 'Airport run');
      expect(named.displayLabel, 'Airport run');

      final blank = _savedTrip(departure: future, label: '   ');
      expect(blank.displayLabel, blank.defaultLabel);
    });

    test('refuses to save an itinerary that did not come from the API', () {
      expect(
        () => SavedTrip.fromItinerary(
          itinerary: Itinerary(
            duration: 60,
            startTime: future,
            endTime: future.add(const Duration(minutes: 1)),
            transfers: 0,
            legs: const [],
          ),
          fromName: 'A',
          fromLat: 0,
          fromLon: 0,
          toName: 'B',
          toLat: 1,
          toLon: 1,
          timeSelection: TimeSelection.now(),
        ),
        throwsArgumentError,
      );
    });

    test('marks a finished trip as past', () {
      final old = _savedTrip(
        departure: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(old.isPast, isTrue);
      expect(_savedTrip(departure: future).isPast, isFalse);
    });
  });

  group('SavedTripsService', () {
    test('saves and reads back a trip', () async {
      await SavedTripsService.saveTrip(_savedTrip(departure: future));

      final trips = await SavedTripsService.getSavedTrips();
      expect(trips, hasLength(1));
      expect(trips.single.toName, 'Airport');
      expect(await SavedTripsService.isSaved(trips.single.id), isTrue);
    });

    test('replaces rather than duplicates the same connection', () async {
      final trip = _savedTrip(departure: future);
      await SavedTripsService.saveTrip(trip);
      await SavedTripsService.saveTrip(_savedTrip(departure: future));

      expect(await SavedTripsService.getSavedTrips(), hasLength(1));
    });

    test('keeps a user label when the same connection is re-saved', () async {
      await SavedTripsService.saveTrip(_savedTrip(departure: future));
      final id = (await SavedTripsService.getSavedTrips()).single.id;
      await SavedTripsService.renameTrip(id, 'Airport run');

      await SavedTripsService.saveTrip(_savedTrip(departure: future));

      final trips = await SavedTripsService.getSavedTrips();
      expect(trips.single.label, 'Airport run');
    });

    test('treats different departures as different trips', () async {
      await SavedTripsService.saveTrip(_savedTrip(departure: future));
      await SavedTripsService.saveTrip(
        _savedTrip(departure: future.add(const Duration(hours: 1))),
      );

      expect(await SavedTripsService.getSavedTrips(), hasLength(2));
    });

    test('returns trips soonest first', () async {
      await SavedTripsService.saveTrip(
        _savedTrip(departure: future.add(const Duration(days: 3))),
      );
      await SavedTripsService.saveTrip(_savedTrip(departure: future));

      final trips = await SavedTripsService.getSavedTrips();
      expect(
        trips.first.departureTime.isBefore(trips.last.departureTime),
        isTrue,
      );
    });

    test('does not cap the list the way recent trips does', () async {
      for (var i = 0; i < 12; i++) {
        await SavedTripsService.saveTrip(
          _savedTrip(departure: future.add(Duration(hours: i))),
        );
      }

      expect(await SavedTripsService.getSavedTrips(), hasLength(12));
    });

    test('renames and clears a label', () async {
      await SavedTripsService.saveTrip(_savedTrip(departure: future));
      final id = (await SavedTripsService.getSavedTrips()).single.id;

      await SavedTripsService.renameTrip(id, 'Airport run');
      expect(
        (await SavedTripsService.getSavedTrips()).single.label,
        'Airport run',
      );

      await SavedTripsService.renameTrip(id, '  ');
      expect((await SavedTripsService.getSavedTrips()).single.label, isNull);
    });

    test('removes a trip', () async {
      await SavedTripsService.saveTrip(_savedTrip(departure: future));
      final id = (await SavedTripsService.getSavedTrips()).single.id;

      await SavedTripsService.removeTrip(id);

      expect(await SavedTripsService.getSavedTrips(), isEmpty);
      expect(await SavedTripsService.isSaved(id), isFalse);
    });

    test('prunes only long-finished trips', () async {
      await SavedTripsService.saveTrip(
        _savedTrip(
          departure: DateTime.now().subtract(const Duration(days: 40)),
        ),
      );
      await SavedTripsService.saveTrip(
        _savedTrip(departure: DateTime.now().subtract(const Duration(days: 2))),
      );
      await SavedTripsService.saveTrip(_savedTrip(departure: future));

      final removed = await SavedTripsService.pruneExpired();

      expect(removed, 1);
      expect(await SavedTripsService.getSavedTrips(), hasLength(2));
    });

    test('publishes changes on the listenable', () async {
      expect(SavedTripsService.savedTripsListenable.value, isEmpty);

      await SavedTripsService.saveTrip(_savedTrip(departure: future));
      expect(SavedTripsService.savedTripsListenable.value, hasLength(1));

      await SavedTripsService.removeTrip(
        SavedTripsService.savedTripsListenable.value.single.id,
      );
      expect(SavedTripsService.savedTripsListenable.value, isEmpty);
    });

    test(
      'skips unreadable entries instead of dropping the whole list',
      () async {
        final good = _savedTrip(departure: future);
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'saved_trips_v1': jsonEncode([
                {'id': 'broken'},
                good.toJson(),
              ]),
            });

        final trips = await SavedTripsService.getSavedTrips();
        expect(trips, hasLength(1));
        expect(trips.single.id, good.id);
      },
    );
  });
}
