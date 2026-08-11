import '../models/itinerary.dart';
import '../models/journey_stop.dart';

/// Every alert worth showing for [leg] and the [stops] it calls at, with
/// repeats removed.
///
/// The same disruption is commonly attached to the leg and to each stop it
/// touches, so alerts are keyed on the text a rider actually reads.
List<Alert> collectTripAlerts(Leg leg, List<JourneyStop> stops) {
  final byText = <String, Alert>{};
  void add(Alert alert) {
    if (!alert.hasText) return;
    byText['${alert.headerText}|${alert.descriptionText}'] = alert;
  }

  for (final stop in stops) {
    stop.alerts.forEach(add);
  }
  leg.alerts.forEach(add);
  return byText.values.toList(growable: false);
}

List<JourneyStop> buildJourneyStops(Leg leg) {
  final stops = <JourneyStop>[];

  stops.add(
    JourneyStop(
      name: leg.fromName,
      stopId: leg.fromStopId,
      lat: leg.fromLat,
      lon: leg.fromLon,
      arrival: null,
      departure: leg.startTime,
      scheduledArrival: null,
      scheduledDeparture: leg.scheduledStartTime,
      track: leg.fromTrack,
      scheduledTrack: leg.fromScheduledTrack,
      cancelled: leg.cancelled,
      alerts: const [],
    ),
  );

  for (final stop in leg.intermediateStops) {
    stops.add(
      JourneyStop(
        name: stop.name,
        stopId: stop.stopId,
        lat: stop.lat,
        lon: stop.lon,
        arrival: stop.arrival,
        departure: stop.departure,
        scheduledArrival: stop.scheduledArrival,
        scheduledDeparture: stop.scheduledDeparture,
        track: stop.track,
        scheduledTrack: stop.scheduledTrack,
        cancelled: stop.cancelled,
        alerts: stop.alerts,
      ),
    );
  }

  stops.add(
    JourneyStop(
      name: leg.toName,
      stopId: leg.toStopId,
      lat: leg.toLat,
      lon: leg.toLon,
      arrival: leg.endTime,
      departure: null,
      scheduledArrival: leg.scheduledEndTime,
      scheduledDeparture: null,
      track: leg.toTrack,
      scheduledTrack: leg.toScheduledTrack,
      cancelled: leg.cancelled,
      alerts: const [],
    ),
  );

  return stops;
}
