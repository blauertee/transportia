import '../../models/transitous/enums.dart';
import '../../models/transitous/json.dart';
import '../../models/transitous/place.dart';
import '../../models/transitous/route_info.dart';
import '../../models/transitous/server_config.dart';
import '../../models/transitous/trip_segment.dart';
import '../query.dart';
import '../transitous_client.dart';
import '../transitous_endpoint.dart';

/// The `/map/*` family.
///
/// Every bounding box here is `lat,lon` for both corners.
class MapEndpoint {
  const MapEndpoint._();

  /// Vehicles in motion inside the box during a time window.
  static Future<List<TripSegment>> trips({
    required double zoom,
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    required DateTime startTime,
    required DateTime endTime,
    int? precision,
    List<String> languages = const [],
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.mapTrips,
      {
        'zoom': Q.number(zoom),
        'min': Q.latLonComma(minLat, minLon),
        'max': Q.latLonComma(maxLat, maxLon),
        'startTime': Q.dateTime(startTime),
        'endTime': Q.dateTime(endTime),
        // Polyline encoding precision; lower means a smaller response.
        'precision': Q.integer(precision),
        'language': Q.csv(languages),
      },
      (json) => asList(json, TripSegment.fromJson),
    );
  }

  /// Stops inside the box.
  static Future<List<TransitPlace>> stops({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    bool? grouped,
    List<TransitMode> modes = const [],
    List<String> languages = const [],
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.mapStops,
      {
        'min': Q.latLonComma(minLat, minLon),
        'max': Q.latLonComma(maxLat, maxLon),
        // Collapse platforms into their parent station.
        'grouped': Q.boolean(grouped),
        'modes': Q.csv(modes.map((m) => m.wireName)),
        'language': Q.csv(languages),
      },
      (json) => asList(json, TransitPlace.fromJson),
    );
  }

  /// Where to centre the map on first load, plus the server's capabilities.
  static Future<InitialMapView> initial({TransitousClient? client}) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.mapInitial,
      const {},
      (json) => InitialMapView.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Indoor levels present in the box, for stations mapped in 3D.
  static Future<List<double>> levels({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.mapLevels,
      {
        'min': Q.latLonComma(minLat, minLon),
        'max': Q.latLonComma(maxLat, maxLon),
      },
      (json) => json is! List
          ? const <double>[]
          : [
              for (final entry in json)
                if (asDouble(entry) case final level?) level,
            ],
    );
  }

  /// Route shapes inside the box, for drawing the transit network.
  ///
  /// Experimental upstream: the response may change without a version bump.
  static Future<MapRoutesResponse> routes({
    required double zoom,
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    List<String> languages = const [],
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.mapRoutes,
      {
        'zoom': Q.number(zoom),
        'min': Q.latLonComma(minLat, minLon),
        'max': Q.latLonComma(maxLat, maxLon),
        'language': Q.csv(languages),
      },
      (json) => MapRoutesResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Segments and stops of one route, keyed by [RouteInfo.routeIndex] from
  /// [routes].
  static Future<MapRoutesResponse> routeDetails({
    required int routeIndex,
    List<String> languages = const [],
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.mapRouteDetails,
      {'routeIdx': Q.integer(routeIndex), 'language': Q.csv(languages)},
      (json) => MapRoutesResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}
