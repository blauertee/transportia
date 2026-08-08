import 'alert.dart';
import 'enums.dart';
import 'json.dart';

/// A point in an itinerary: a stop, an address or a plain coordinate.
///
/// MOTIS returns this same `Place` object for leg endpoints, intermediate
/// stops, stop times and `/stop`, so the app models it once. Only `name`,
/// `lat` and `lon` are guaranteed; everything else depends on what the place
/// is and which endpoint returned it.
class TransitPlace {
  const TransitPlace({
    required this.name,
    required this.lat,
    required this.lon,
    this.stopId,
    this.parentId,
    this.importance,
    this.level,
    this.tz,
    this.arrival,
    this.departure,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.track,
    this.scheduledTrack,
    this.stopCode,
    this.description,
    this.vertexType,
    this.pickupType,
    this.dropoffType,
    this.cancelled = false,
    this.alerts = const [],
    this.flex,
    this.flexId,
    this.flexStartPickupDropOffWindow,
    this.flexEndPickupDropOffWindow,
    this.modes = const [],
  });

  final String name;
  final double lat;
  final double lon;

  /// Feed-prefixed stop id, e.g. `de-DELFI_de:11000:900100003`.
  ///
  /// This is the form `via` and `/stoptimes` expect; a bare GTFS id is
  /// rejected with `unknown feed id ""`.
  final String? stopId;

  /// Parent station of this stop, when it is a platform or track.
  final String? parentId;

  /// Geocoder relevance, only present on search results.
  final double? importance;

  /// Indoor level, for stations mapped in 3D.
  final double? level;

  /// IANA timezone of the stop.
  final String? tz;

  final DateTime? arrival;
  final DateTime? departure;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;

  /// Real-time platform, which may differ from [scheduledTrack].
  final String? track;
  final String? scheduledTrack;

  /// Rider-facing stop code, as printed at the stop.
  final String? stopCode;
  final String? description;

  final VertexType? vertexType;
  final PickupDropoffType? pickupType;
  final PickupDropoffType? dropoffType;

  final bool cancelled;
  final List<Alert> alerts;

  /// Flexible-transport (demand-responsive) area name, when this place is
  /// served by a flex zone rather than a fixed stop.
  final String? flex;
  final String? flexId;
  final DateTime? flexStartPickupDropOffWindow;
  final DateTime? flexEndPickupDropOffWindow;

  /// Modes served at this stop, when the endpoint reports them.
  final List<TransitMode> modes;

  /// True when the place is a timetabled stop rather than a coordinate.
  bool get isStop => stopId != null && stopId!.isNotEmpty;

  /// Best known arrival, preferring real-time over scheduled.
  DateTime? get effectiveArrival => arrival ?? scheduledArrival;

  /// Best known departure, preferring real-time over scheduled.
  DateTime? get effectiveDeparture => departure ?? scheduledDeparture;

  /// Delay against the scheduled departure, or null when either is unknown.
  Duration? get departureDelay =>
      (departure == null || scheduledDeparture == null)
      ? null
      : departure!.difference(scheduledDeparture!);

  /// Delay against the scheduled arrival, or null when either is unknown.
  Duration? get arrivalDelay => (arrival == null || scheduledArrival == null)
      ? null
      : arrival!.difference(scheduledArrival!);

  factory TransitPlace.fromJson(Map<String, dynamic> json) {
    return TransitPlace(
      name: asString(json['name']) ?? '',
      lat: asDouble(json['lat']) ?? 0.0,
      lon: asDouble(json['lon']) ?? 0.0,
      stopId: asString(json['stopId']),
      parentId: asString(json['parentId']),
      importance: asDouble(json['importance']),
      level: asDouble(json['level']),
      tz: asString(json['tz']),
      arrival: asDateTime(json['arrival']),
      departure: asDateTime(json['departure']),
      scheduledArrival: asDateTime(json['scheduledArrival']),
      scheduledDeparture: asDateTime(json['scheduledDeparture']),
      track: asString(json['track']),
      scheduledTrack: asString(json['scheduledTrack']),
      stopCode: asString(json['stopCode']),
      description: asString(json['description']),
      vertexType: VertexType.fromWire(json['vertexType']),
      pickupType: PickupDropoffType.fromWire(json['pickupType']),
      dropoffType: PickupDropoffType.fromWire(json['dropoffType']),
      cancelled: asBool(json['cancelled']) ?? false,
      alerts: asList(json['alerts'], Alert.fromJson),
      flex: asString(json['flex']),
      flexId: asString(json['flexId']),
      flexStartPickupDropOffWindow: asDateTime(
        json['flexStartPickupDropOffWindow'],
      ),
      flexEndPickupDropOffWindow: asDateTime(
        json['flexEndPickupDropOffWindow'],
      ),
      modes: _modes(json['modes']),
    );
  }

  static List<TransitMode> _modes(Object? raw) {
    if (raw is! List) return const [];
    return List.unmodifiable([
      for (final entry in raw)
        if (TransitMode.fromWire(entry) case final mode?) mode,
    ]);
  }
}
