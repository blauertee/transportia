import '../api/endpoints/trip_endpoint.dart';
import '../models/itinerary.dart';
import '../models/transitous/itinerary_id.dart';
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

/// Signature of the whole-itinerary refresh, so tests can supply their own
/// result without going over the network.
typedef ItineraryFetcher = Future<Itinerary> Function(Itinerary itinerary);

/// Re-fetches real-time data for the transit legs of an itinerary.
///
/// An itinerary is a snapshot of what the planner returned. Delays, track
/// changes and cancellations land afterwards, so any screen that shows an
/// itinerary it did not just fetch needs to re-check it.
class ItineraryRefreshService {
  const ItineraryRefreshService._();

  /// Re-checks [itinerary] against current real-time data.
  ///
  /// Prefers `/refresh-itinerary`, which re-plans the whole journey in one
  /// request. Falls back to a `/trip` lookup per distinct trip when that is
  /// unavailable — for an itinerary restored from an older saved trip, or
  /// when the endpoint fails.
  ///
  /// The returned itinerary is [itinerary] itself when nothing could be
  /// refreshed; read [ItineraryRefreshResult.freshness] to tell the cases
  /// apart rather than inferring it from the itinerary.
  static Future<ItineraryRefreshResult> refresh(
    Itinerary itinerary, {
    TripDetailsFetcher? fetchTripDetails,
    ItineraryFetcher? fetchItinerary,
  }) async {
    if (!_hasTransitLegs(itinerary)) {
      return ItineraryRefreshResult(
        itinerary: itinerary,
        freshness: ItineraryFreshness.notRefreshable,
      );
    }

    // The single-request path. Only skipped when a caller has pinned the
    // per-trip fetcher, which is how the older tests drive this.
    if (fetchTripDetails == null) {
      final refreshed = await _refreshWhole(
        itinerary,
        fetchItinerary ?? _refreshViaApi,
      );
      if (refreshed != null) return refreshed;
    }

    return _refreshPerTrip(
      itinerary,
      fetchTripDetails ?? TripDetailsService.fetchTripDetails,
    );
  }

  static bool _hasTransitLegs(Itinerary itinerary) =>
      itinerary.legs.any((leg) => leg.tripId != null && leg.tripId!.isNotEmpty);

  /// Refreshes the itinerary in one request, or returns null so the caller
  /// falls back to the per-trip path.
  static Future<ItineraryRefreshResult?> _refreshWhole(
    Itinerary itinerary,
    ItineraryFetcher fetch,
  ) async {
    final Itinerary fresh;
    try {
      fresh = await fetch(itinerary);
    } catch (_) {
      return null;
    }
    if (fresh.legs.length != itinerary.legs.length) {
      // The server re-planned rather than refreshed, so the legs no longer
      // line up with what is on screen. Fall back rather than swap the
      // journey out from under the user.
      return null;
    }

    return ItineraryRefreshResult(
      itinerary: fresh,
      freshness: fresh.legs.any((leg) => leg.cancelled)
          ? ItineraryFreshness.changed
          : ItineraryFreshness.live,
    );
  }

  static Future<Itinerary> _refreshViaApi(Itinerary itinerary) {
    final id = itinerary.id;
    // A saved trip parsed from a snapshot taken before the app read `id`
    // still has its legs, which is enough to rebuild the structured form.
    return id != null && id.isNotEmpty
        ? TripEndpoint.refreshItinerary(itineraryId: id)
        : TripEndpoint.refreshItineraryById(
            id: ItineraryId.fromItinerary(itinerary),
          );
  }

  static Future<ItineraryRefreshResult> _refreshPerTrip(
    Itinerary itinerary,
    TripDetailsFetcher fetch,
  ) async {
    final tripIds = itinerary.legs
        .map((leg) => leg.tripId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

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
