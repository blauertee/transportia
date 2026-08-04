import '../models/itinerary.dart';
import 'trip_details_service.dart';

/// Re-fetches real-time data for the transit legs of an itinerary.
///
/// An itinerary is a snapshot of what the planner returned. Delays, track
/// changes and cancellations land afterwards, so any screen that shows an
/// itinerary it did not just fetch needs to re-check it.
class ItineraryRefreshService {
  const ItineraryRefreshService._();

  /// Looks up every distinct `tripId` in [itinerary] and merges the fresh
  /// real-time fields back into the matching legs.
  ///
  /// Returns null when [itinerary] has no transit legs to refresh — walking
  /// directions never go stale, so there is nothing to report. Otherwise
  /// returns the itinerary, which is unchanged if none of the lookups
  /// produced anything.
  static Future<Itinerary?> refresh(Itinerary itinerary) async {
    final tripIds = itinerary.legs
        .map((leg) => leg.tripId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    if (tripIds.isEmpty) return null;

    final updates = <String, Leg>{};
    await Future.wait(
      tripIds.map((tripId) async {
        try {
          final details = await TripDetailsService.fetchTripDetails(
            tripId: tripId,
          );
          if (details.legs.isNotEmpty) {
            updates[tripId] = details.legs.first;
          }
        } catch (_) {}
      }),
    );

    if (updates.isEmpty) return itinerary;

    final newLegs = itinerary.legs.map((leg) {
      final fresh = leg.tripId != null ? updates[leg.tripId] : null;
      return fresh != null ? leg.withRealTimeFrom(fresh) : leg;
    }).toList();

    return itinerary.withLegs(newLegs);
  }
}
