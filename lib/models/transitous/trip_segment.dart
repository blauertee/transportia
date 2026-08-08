import 'enums.dart';
import 'json.dart';
import 'place.dart';

/// One trip serving a segment.
class TripInfo {
  const TripInfo({required this.tripId, this.routeShortName, this.displayName});

  final String tripId;
  final String? routeShortName;
  final String? displayName;

  factory TripInfo.fromJson(Map<String, dynamic> json) => TripInfo(
    tripId: asString(json['tripId']) ?? '',
    routeShortName: asString(json['routeShortName']),
    displayName: asString(json['displayName']),
  );
}

/// A stretch of track or road with vehicles on it, from `/map/trips`.
///
/// One segment can carry several trips when different services share the same
/// stretch during the requested window.
class TripSegment {
  const TripSegment({
    required this.trips,
    required this.from,
    required this.to,
    required this.departure,
    required this.arrival,
    this.scheduledDeparture,
    this.scheduledArrival,
    this.mode,
    this.routeColor,
    this.distance,
    this.realTime = false,
    this.polyline,
  });

  final List<TripInfo> trips;
  final TransitPlace from;
  final TransitPlace to;
  final DateTime departure;
  final DateTime arrival;
  final DateTime? scheduledDeparture;
  final DateTime? scheduledArrival;
  final TransitMode? mode;
  final String? routeColor;

  /// Metres along the segment.
  final double? distance;

  final bool realTime;

  /// Encoded polyline of the segment's shape.
  final String? polyline;

  /// First trip on the segment; the one worth labelling it with.
  TripInfo? get primaryTrip => trips.isEmpty ? null : trips.first;

  factory TripSegment.fromJson(Map<String, dynamic> json) => TripSegment(
    trips: asList(json['trips'], TripInfo.fromJson),
    from: TransitPlace.fromJson(asMap(json['from']) ?? const {}),
    to: TransitPlace.fromJson(asMap(json['to']) ?? const {}),
    departure: asDateTime(json['departure']) ?? DateTime.now().toUtc(),
    arrival: asDateTime(json['arrival']) ?? DateTime.now().toUtc(),
    scheduledDeparture: asDateTime(json['scheduledDeparture']),
    scheduledArrival: asDateTime(json['scheduledArrival']),
    mode: TransitMode.fromWire(json['mode']),
    routeColor: asString(json['routeColor']),
    distance: asDouble(json['distance']),
    realTime: asBool(json['realTime']) ?? false,
    polyline: asString(json['polyline']),
  );
}
