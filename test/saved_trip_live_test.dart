import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/saved_trip.dart';
import 'package:transportia/services/itinerary_refresh_service.dart';
import 'package:transportia/services/saved_trips_service.dart';

import 'support/plan_fixtures.dart';

/// Keeping a journey means keeping *that* journey. A live check may update the
/// times on it; it may not quietly replace it with a different connection.
SavedTrip _trip({required DateTime departure}) => SavedTrip.fromItinerary(
  itinerary: Itinerary.fromJson(planItineraryJson(departure: departure)),
);

Itinerary _refreshed({required DateTime departure}) =>
    Itinerary.fromJson(planItineraryJson(departure: departure));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('what may be written over a saved trip', () {
    test('a live check that reached data may', () {
      expect(
        SavedTripsService.shouldStoreLiveResult(
          didRefresh: true,
          freshness: ItineraryFreshness.live,
        ),
        isTrue,
      );
    });

    test('a check that reached nothing may not', () {
      // Nothing was learned, so there is nothing to keep.
      expect(
        SavedTripsService.shouldStoreLiveResult(
          didRefresh: false,
          freshness: ItineraryFreshness.live,
        ),
        isFalse,
      );
    });

    test('a check that came back with a different connection may not', () {
      // This is the one that matters: overwriting here would destroy the
      // journey the rider chose to keep.
      expect(
        SavedTripsService.shouldStoreLiveResult(
          didRefresh: true,
          freshness: ItineraryFreshness.changed,
        ),
        isFalse,
      );
    });
  });

  group('storing a live result', () {
    test('updates the stored times and stamps when', () async {
      final departure = DateTime.now().add(const Duration(hours: 2));
      final trip = _trip(departure: departure);
      await SavedTripsService.saveTrip(trip);

      final later = departure.add(const Duration(minutes: 6));
      final at = DateTime.now();
      await SavedTripsService.storeLiveItinerary(
        id: trip.id,
        refreshed: _refreshed(departure: later),
        didRefresh: true,
        freshness: ItineraryFreshness.live,
        at: at,
      );

      final stored = (await SavedTripsService.getSavedTrips()).single;
      expect(stored.liveUpdatedAt, at);
      expect(stored.itinerary.startTime.toUtc(), later.toUtc());
      // Reopening reads the kept snapshot, so the new times survive a restart.
      expect(stored.departureTime.toUtc(), later.toUtc());
    });

    test('a changed connection leaves the trip exactly as it was', () async {
      final departure = DateTime.now().add(const Duration(hours: 2));
      final trip = _trip(departure: departure);
      await SavedTripsService.saveTrip(trip);

      await SavedTripsService.storeLiveItinerary(
        id: trip.id,
        refreshed: _refreshed(
          departure: departure.add(const Duration(days: 1)),
        ),
        didRefresh: true,
        freshness: ItineraryFreshness.changed,
      );

      final stored = (await SavedTripsService.getSavedTrips()).single;
      expect(stored.liveUpdatedAt, isNull);
      expect(stored.departureTime, trip.departureTime);
    });

    test('a trip that is not saved is not created by a refresh', () async {
      await SavedTripsService.storeLiveItinerary(
        id: 'never-saved',
        refreshed: _refreshed(
          departure: DateTime.now().add(const Duration(hours: 2)),
        ),
        didRefresh: true,
        freshness: ItineraryFreshness.live,
      );

      expect(await SavedTripsService.getSavedTrips(), isEmpty);
    });

    test('the stamp survives a round trip through storage', () async {
      final departure = DateTime.now().add(const Duration(hours: 2));
      final trip = _trip(departure: departure);
      await SavedTripsService.saveTrip(trip);

      final at = DateTime.now();
      await SavedTripsService.storeLiveItinerary(
        id: trip.id,
        refreshed: _refreshed(departure: departure),
        didRefresh: true,
        freshness: ItineraryFreshness.live,
        at: at,
      );

      // Re-read from scratch, which is what a restart does.
      final reread = SavedTrip.fromJson(
        (await SavedTripsService.getSavedTrips()).single.toJson(),
      );
      expect(reread.liveUpdatedAt?.toIso8601String(), at.toIso8601String());
    });
  });
}
