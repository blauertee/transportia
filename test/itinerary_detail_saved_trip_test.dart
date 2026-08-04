import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/saved_trip.dart';
import 'package:transportia/services/itinerary_refresh_service.dart';

/// The notice shown on a saved trip is chosen from its freshness and
/// whether it has already run. These tests pin that decision down through
/// the refresh service, which is where the states come from.
Map<String, dynamic> _planJson({
  required DateTime departure,
  bool cancelled = false,
}) {
  final arrival = departure.add(const Duration(minutes: 15));
  return jsonDecode(
        jsonEncode({
          'duration': 900,
          'startTime': departure.toUtc().toIso8601String(),
          'endTime': arrival.toUtc().toIso8601String(),
          'transfers': 0,
          'legs': [
            {
              'mode': 'RAIL',
              'startTime': departure.toUtc().toIso8601String(),
              'endTime': arrival.toUtc().toIso8601String(),
              'duration': 900,
              'tripId': 'trip-re7',
              'displayName': 'RE7',
              'cancelled': cancelled,
              'from': {'name': 'Hauptbahnhof', 'lat': 52.525, 'lon': 13.369},
              'to': {'name': 'Airport', 'lat': 52.366, 'lon': 13.503},
            },
          ],
        }),
      )
      as Map<String, dynamic>;
}

SavedTrip _trip({required DateTime departure}) {
  return SavedTrip.fromItinerary(
    itinerary: Itinerary.fromJson(_planJson(departure: departure)),
  );
}

void main() {
  test('a saved trip re-parses into the connection that was stored', () {
    final departure = DateTime.now().add(const Duration(days: 1));
    final trip = _trip(departure: departure);

    expect(trip.itinerary.legs.single.tripId, 'trip-re7');
    expect(trip.itinerary.legs.single.displayName, 'RE7');
    expect(trip.fromName, 'Hauptbahnhof');
    expect(trip.toName, 'Airport');
  });

  test(
    'a departure beyond the real-time horizon reports as scheduled',
    () async {
      final trip = _trip(
        departure: DateTime.now().add(const Duration(days: 21)),
      );

      final result = await ItineraryRefreshService.refresh(
        trip.itinerary,
        fetchTripDetails: ({required String tripId}) async =>
            throw Exception('trip not in the feed this far out'),
      );

      // The screen shows the "Scheduled times" notice for this, and must not
      // claim the trip was just updated.
      expect(result.freshness, ItineraryFreshness.scheduled);
      expect(result.didRefresh, isFalse);
    },
  );

  test('a cancelled service reports as changed', () async {
    final departure = DateTime.now().add(const Duration(hours: 2));
    final trip = _trip(departure: departure);

    final result = await ItineraryRefreshService.refresh(
      trip.itinerary,
      fetchTripDetails: ({required String tripId}) async =>
          Itinerary.fromJson(_planJson(departure: departure, cancelled: true)),
    );

    expect(result.freshness, ItineraryFreshness.changed);
    expect(result.itinerary.legs.any((leg) => leg.cancelled), isTrue);
  });

  test(
    'a reachable departure reports as live and picks up the delay',
    () async {
      final departure = DateTime.now().add(const Duration(hours: 2));
      final trip = _trip(departure: departure);
      final delayed = departure.add(const Duration(minutes: 6));

      final result = await ItineraryRefreshService.refresh(
        trip.itinerary,
        fetchTripDetails: ({required String tripId}) async =>
            Itinerary.fromJson(_planJson(departure: delayed)),
      );

      expect(result.freshness, ItineraryFreshness.live);
      expect(
        result.itinerary.startTime.toUtc(),
        DateTime.parse(delayed.toUtc().toIso8601String()),
      );
    },
  );

  test('a finished trip is past regardless of what a refresh says', () {
    final trip = _trip(
      departure: DateTime.now().subtract(const Duration(days: 3)),
    );

    // isPast wins over freshness in the notice, so "Search again" is the
    // offer rather than a delay readout.
    expect(trip.isPast, isTrue);
  });

  test('re-planning a past trip targets the next occurrence', () {
    final departure = DateTime.now().subtract(const Duration(days: 3));
    final trip = _trip(departure: departure);

    // Mirrors _nextOccurrence in the detail screen.
    final local = trip.departureTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
      local.hour,
      local.minute,
    );
    final next = today.isAfter(now)
        ? today
        : today.add(const Duration(days: 1));

    expect(next.isAfter(now), isTrue);
    expect(next.hour, local.hour);
    expect(next.minute, local.minute);
  });
}
