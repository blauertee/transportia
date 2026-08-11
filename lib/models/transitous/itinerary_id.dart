import '../itinerary.dart' show Itinerary, Leg;
import 'json.dart';

/// Structured identifier for one leg, as `/refresh-itinerary` expects in a
/// POST body.
///
/// It pins the leg by its schedule and endpoints rather than by an opaque
/// handle, which is what lets the server re-find the same service after a
/// real-time update.
class LegId {
  const LegId({
    required this.displayName,
    required this.tripId,
    required this.fromId,
    required this.fromLat,
    required this.fromLon,
    required this.toId,
    required this.toLat,
    required this.toLon,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.mode,
    required this.scheduled,
    this.fromLevel,
    this.toLevel,
  });

  final String displayName;
  final String tripId;
  final String fromId;
  final double fromLat;
  final double fromLon;
  final double? fromLevel;
  final String toId;
  final double toLat;
  final double toLon;
  final double? toLevel;

  /// Scheduled departure, sent as a Unix timestamp in seconds.
  final DateTime scheduledStart;

  /// Scheduled arrival, sent as a Unix timestamp in seconds.
  final DateTime scheduledEnd;

  final String mode;
  final bool scheduled;

  /// Builds the identifier for [leg].
  ///
  /// Falls back to the leg's real times when it carries no scheduled ones,
  /// which is the case for street legs.
  factory LegId.fromLeg(Leg leg) => LegId(
    displayName: leg.displayName ?? '',
    tripId: leg.tripId ?? '',
    fromId: leg.from.stopId ?? '',
    fromLat: leg.from.lat,
    fromLon: leg.from.lon,
    fromLevel: leg.from.level,
    toId: leg.to.stopId ?? '',
    toLat: leg.to.lat,
    toLon: leg.to.lon,
    toLevel: leg.to.level,
    scheduledStart: leg.scheduledStartTime ?? leg.startTime,
    scheduledEnd: leg.scheduledEndTime ?? leg.endTime,
    mode: leg.mode,
    scheduled: leg.scheduled,
  );

  factory LegId.fromJson(Map<String, dynamic> json) => LegId(
    displayName: asString(json['displayName']) ?? '',
    tripId: asString(json['tripId']) ?? '',
    fromId: asString(json['fromId']) ?? '',
    fromLat: asDouble(json['fromLat']) ?? 0.0,
    fromLon: asDouble(json['fromLon']) ?? 0.0,
    fromLevel: asDouble(json['fromLevel']),
    toId: asString(json['toId']) ?? '',
    toLat: asDouble(json['toLat']) ?? 0.0,
    toLon: asDouble(json['toLon']) ?? 0.0,
    toLevel: asDouble(json['toLevel']),
    scheduledStart: _fromUnix(json['schedStart']),
    scheduledEnd: _fromUnix(json['schedEnd']),
    mode: asString(json['mode']) ?? 'WALK',
    scheduled: asBool(json['scheduled']) ?? true,
  );

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'tripId': tripId,
    'fromId': fromId,
    'fromLat': fromLat,
    'fromLon': fromLon,
    if (fromLevel != null) 'fromLevel': fromLevel,
    'toId': toId,
    'toLat': toLat,
    'toLon': toLon,
    if (toLevel != null) 'toLevel': toLevel,
    'schedStart': scheduledStart.millisecondsSinceEpoch ~/ 1000,
    'schedEnd': scheduledEnd.millisecondsSinceEpoch ~/ 1000,
    'mode': mode,
    'scheduled': scheduled,
  };

  static DateTime _fromUnix(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(
        (asInt(value) ?? 0) * 1000,
        isUtc: true,
      );
}

/// Structured identifier for a whole itinerary.
///
/// This is what the POST form of `/refresh-itinerary` takes. The opaque
/// [Itinerary.id] string is a different encoding of the same thing and only
/// works with the GET form — the server rejects it in a POST body with
/// `value is not an object`.
class ItineraryId {
  const ItineraryId({required this.legs});

  final List<LegId> legs;

  factory ItineraryId.fromItinerary(Itinerary itinerary) =>
      ItineraryId(legs: itinerary.legs.map(LegId.fromLeg).toList());

  factory ItineraryId.fromJson(Map<String, dynamic> json) =>
      ItineraryId(legs: asList(json['legs'], LegId.fromJson));

  Map<String, dynamic> toJson() => {
    'legs': [for (final leg in legs) leg.toJson()],
  };
}
