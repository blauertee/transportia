import 'itinerary.dart';

class JourneyStop {
  const JourneyStop({
    required this.name,
    this.stopId,
    required this.lat,
    required this.lon,
    required this.arrival,
    required this.departure,
    required this.scheduledArrival,
    required this.scheduledDeparture,
    required this.track,
    required this.scheduledTrack,
    required this.cancelled,
    required this.alerts,
  });

  final String name;
  final String? stopId;
  final double lat;
  final double lon;
  final DateTime? arrival;
  final DateTime? departure;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;
  final String? track;
  final String? scheduledTrack;
  final bool cancelled;
  final List<Alert> alerts;

  /// The one time that matters at this stop: when the vehicle leaves, or when
  /// it arrives if it never leaves again.
  DateTime? get timeAtStop => departure ?? arrival;

  /// [timeAtStop] read from the far end — at a terminus the arrival is the
  /// moment that matters.
  DateTime? get timeAtTerminus => arrival ?? departure;
}
