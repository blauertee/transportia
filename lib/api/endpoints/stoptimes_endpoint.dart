import '../../models/stop_time.dart';
import '../../models/transitous/enums.dart';
import '../../models/transitous/json.dart';
import '../../models/transitous/place.dart';
import '../../models/transitous/route_info.dart';
import '../query.dart';
import '../transitous_client.dart';
import '../transitous_endpoint.dart';

/// `/stoptimes` and `/stop`.
class StopTimesEndpoint {
  const StopTimesEndpoint._();

  /// Departures or arrivals at a stop.
  static Future<StopTimesResponse> stopTimes({
    String? stopId,
    double? centerLat,
    double? centerLon,
    DateTime? time,
    bool? arriveBy,
    bool? both,
    String? direction,
    Duration? window,
    List<TransitMode> modes = const [],
    int? n,
    double? radius,
    bool? exactRadius,
    bool? fetchStops,
    String? pageCursor,
    bool? withScheduledSkippedStops,
    RealtimeMode? realtimeMode,
    List<String> languages = const [],
    bool? withAlerts,
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.stopTimes,
      {
        'stopId': stopId,
        'center': centerLat == null || centerLon == null
            ? null
            : Q.latLonComma(centerLat, centerLon),
        'time': Q.dateTime(time),
        'arriveBy': Q.boolean(arriveBy),
        // Return both arrivals and departures rather than only one.
        'both': Q.boolean(both),
        'direction': direction,
        'window': Q.minutes(window),
        'mode': Q.csv(modes.map((m) => m.wireName)),
        'n': Q.integer(n),
        'radius': Q.number(radius),
        'exactRadius': Q.boolean(exactRadius),
        // Include the stop objects rather than ids alone.
        'fetchStops': Q.boolean(fetchStops),
        'pageCursor': pageCursor,
        'withScheduledSkippedStops': Q.boolean(withScheduledSkippedStops),
        'realtimeMode': realtimeMode?.wireName,
        'language': Q.csv(languages),
        'withAlerts': Q.boolean(withAlerts),
      },
      (json) => StopTimesResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Details of one stop, including the modes served there.
  ///
  /// Give either [stopId] or a centre coordinate with a [radius].
  static Future<StopResponse> stop({
    String? stopId,
    double? centerLat,
    double? centerLon,
    double? radius,
    bool? exactRadius,
    List<String> languages = const [],
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.stop,
      {
        'stopId': stopId,
        'center': centerLat == null || centerLon == null
            ? null
            : Q.latLonComma(centerLat, centerLon),
        'radius': Q.number(radius),
        'exactRadius': Q.boolean(exactRadius),
        'language': Q.csv(languages),
      },
      (json) => StopResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}

/// Response of `/stop`: the stop itself plus the lines that serve it.
class StopResponse {
  const StopResponse({required this.place, this.routes = const []});

  final TransitPlace place;
  final List<StopRoute> routes;

  factory StopResponse.fromJson(Map<String, dynamic> json) => StopResponse(
    place: TransitPlace.fromJson(asMap(json['place']) ?? const {}),
    routes: asList(json['routes'], StopRoute.fromJson),
  );
}
