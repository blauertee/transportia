import '../models/itinerary.dart';
import 'trip_details_service.dart';

/// How much the app actually knows about an itinerary's current state after
/// trying to refresh it.
enum ItineraryFreshness {
  /// No transit legs to re-check — walking directions never go stale.
  notRefreshable,

  /// Live data came back and has been merged in.
  live,

  /// The lookups ran but the feed returned nothing, so the times on screen
  /// are still the planned ones. Usually means the departure is beyond the
  /// real-time horizon, which is the normal case for a trip saved days or
  /// weeks ahead.
  scheduled,

  /// Live data came back and says the connection no longer works as
  /// planned — at least one leg is cancelled.
  changed,
}

/// The outcome of refreshing an itinerary.
class ItineraryRefreshResult {
  const ItineraryRefreshResult({
    required this.itinerary,
    required this.freshness,
  });

  final Itinerary itinerary;
  final ItineraryFreshness freshness;

  /// Whether live data actually arrived. Only then has anything been
  /// "updated" — callers use this to decide whether to move a
  /// last-updated timestamp, so that a failed lookup cannot masquerade as
  /// a successful refresh.
  bool get didRefresh =>
      freshness == ItineraryFreshness.live ||
      freshness == ItineraryFreshness.changed;
}

/// Signature of [TripDetailsService.fetchTripDetails], so tests can supply
/// their own trip data without going over the network.
typedef TripDetailsFetcher =
    Future<Itinerary> Function({required String tripId});

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
  /// The returned itinerary is [itinerary] itself when nothing could be
  /// refreshed; read [ItineraryRefreshResult.freshness] to tell the cases
  /// apart rather than inferring it from the itinerary.
  static Future<ItineraryRefreshResult> refresh(
    Itinerary itinerary, {
    TripDetailsFetcher? fetchTripDetails,
  }) async {
    final fetch = fetchTripDetails ?? TripDetailsService.fetchTripDetails;

    final tripIds = itinerary.legs
        .map((leg) => leg.tripId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    if (tripIds.isEmpty) {
      return ItineraryRefreshResult(
        itinerary: itinerary,
        freshness: ItineraryFreshness.notRefreshable,
      );
    }

    final updates = <String, Leg>{};
    await Future.wait(
      tripIds.map((tripId) async {
        try {
          final details = await fetch(tripId: tripId);
          if (details.legs.isNotEmpty) {
            updates[tripId] = details.legs.first;
          }
        } catch (_) {}
      }),
    );

    // Every lookup failed or came back empty. The itinerary is untouched and
    // we know nothing new about it, so say so instead of reporting a refresh.
    if (updates.isEmpty) {
      return ItineraryRefreshResult(
        itinerary: itinerary,
        freshness: ItineraryFreshness.scheduled,
      );
    }

    final newLegs = itinerary.legs.map((leg) {
      final fresh = leg.tripId != null ? updates[leg.tripId] : null;
      return fresh != null ? leg.withRealTimeFrom(fresh) : leg;
    }).toList();

    return ItineraryRefreshResult(
      itinerary: itinerary.withLegs(newLegs),
      freshness: newLegs.any((leg) => leg.cancelled)
          ? ItineraryFreshness.changed
          : ItineraryFreshness.live,
    );
  }
}
