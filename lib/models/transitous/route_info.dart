import '../itinerary.dart' show EncodedPolyline;
import 'enums.dart';
import 'json.dart';
import 'place.dart';

/// Where the geometry of a route came from.
enum RoutePathSource with WireEnum {
  /// No shape available; the route is drawn as straight lines between stops.
  none('NONE'),

  /// Shapes published in the timetable feed.
  timetable('TIMETABLE'),

  /// Shapes computed by street routing.
  routed('ROUTED');

  const RoutePathSource(this.wireName);

  @override
  final String wireName;

  static RoutePathSource? fromWire(Object? raw) => enumFromWire(values, raw);
}

/// A transit line served by a route.
class TransitRouteInfo {
  const TransitRouteInfo({
    required this.id,
    required this.shortName,
    required this.longName,
    this.color,
    this.textColor,
  });

  final String id;
  final String shortName;
  final String longName;
  final String? color;
  final String? textColor;

  factory TransitRouteInfo.fromJson(Map<String, dynamic> json) =>
      TransitRouteInfo(
        id: asString(json['id']) ?? '',
        shortName: asString(json['shortName']) ?? '',
        longName: asString(json['longName']) ?? '',
        color: asString(json['color']),
        textColor: asString(json['textColor']),
      );
}

/// One hop of a route, given as indexes into the response's shared `stops`
/// and `polylines` arrays rather than inline geometry.
class RouteSegment {
  const RouteSegment({
    required this.fromIndex,
    required this.toIndex,
    required this.polylineIndex,
  });

  /// Index into [MapRoutesResponse.stops].
  final int fromIndex;

  /// Index into [MapRoutesResponse.stops].
  final int toIndex;

  /// Index into [MapRoutesResponse.polylines].
  final int polylineIndex;

  factory RouteSegment.fromJson(Map<String, dynamic> json) => RouteSegment(
    fromIndex: asInt(json['from']) ?? 0,
    toIndex: asInt(json['to']) ?? 0,
    polylineIndex: asInt(json['polyline']) ?? 0,
  );
}

/// A polyline shared by every route that runs over it, so a corridor served
/// by several lines is only sent once.
class RoutePolyline {
  const RoutePolyline({
    required this.polyline,
    this.colors = const [],
    this.routeIndexes = const [],
  });

  final EncodedPolyline polyline;

  /// Distinct colours of the routes using this polyline, for drawing a
  /// multi-line corridor.
  final List<String> colors;

  /// Indexes into [MapRoutesResponse.routes].
  final List<int> routeIndexes;

  factory RoutePolyline.fromJson(Map<String, dynamic> json) => RoutePolyline(
    polyline: EncodedPolyline.fromJson(asMap(json['polyline']) ?? const {}),
    colors: asStringList(json['colors']),
    routeIndexes: [
      if (json['routeIndexes'] is List)
        for (final v in json['routeIndexes'] as List)
          if (asInt(v) case final i?) i,
    ],
  );
}

/// A route to draw on the map.
class RouteInfo {
  const RouteInfo({
    required this.mode,
    required this.routeIndex,
    required this.numStops,
    this.transitRoutes = const [],
    this.pathSource,
    this.segments = const [],
  });

  final TransitMode? mode;

  /// Server-side index of this route, the value `/map/route-details` takes.
  final int routeIndex;

  final int numStops;

  /// Lines served by this route.
  final List<TransitRouteInfo> transitRoutes;

  final RoutePathSource? pathSource;

  /// Empty until `/map/route-details` is called for [routeIndex].
  final List<RouteSegment> segments;

  factory RouteInfo.fromJson(Map<String, dynamic> json) => RouteInfo(
    mode: TransitMode.fromWire(json['mode']),
    routeIndex: asInt(json['routeIdx']) ?? 0,
    numStops: asInt(json['numStops']) ?? 0,
    transitRoutes: asList(json['transitRoutes'], TransitRouteInfo.fromJson),
    pathSource: RoutePathSource.fromWire(json['pathSource']),
    segments: asList(json['segments'], RouteSegment.fromJson),
  );
}

/// Response of `/map/routes` and `/map/route-details`.
///
/// Routes reference [stops] and [polylines] by index, so the three lists have
/// to be kept together.
class MapRoutesResponse {
  const MapRoutesResponse({
    this.routes = const [],
    this.polylines = const [],
    this.stops = const [],
    this.zoomFiltered = false,
  });

  final List<RouteInfo> routes;
  final List<RoutePolyline> polylines;
  final List<TransitPlace> stops;

  /// True when the server dropped routes because the zoom level was too low,
  /// meaning the response is not the full picture.
  final bool zoomFiltered;

  factory MapRoutesResponse.fromJson(Map<String, dynamic> json) =>
      MapRoutesResponse(
        routes: asList(json['routes'], RouteInfo.fromJson),
        polylines: asList(json['polylines'], RoutePolyline.fromJson),
        stops: asList(json['stops'], TransitPlace.fromJson),
        zoomFiltered: asBool(json['zoomFiltered']) ?? false,
      );
}

/// How long it takes to transfer to a nearby stop, per profile.
///
/// Every duration is optional and in minutes: a missing value means no path
/// was found for that profile, not zero.
class Transfer {
  const Transfer({
    required this.to,
    this.defaultDuration,
    this.foot,
    this.footRouted,
    this.wheelchair,
    this.wheelchairRouted,
    this.wheelchairUsesElevator,
    this.car,
  });

  final TransitPlace to;

  /// Transfer time published in the GTFS feed.
  final Duration? defaultDuration;

  final Duration? foot;

  /// Foot transfer computed by street routing, rather than taken from the
  /// timetable.
  final Duration? footRouted;

  final Duration? wheelchair;
  final Duration? wheelchairRouted;

  /// True when the wheelchair path depends on an elevator, which matters when
  /// one is out of service.
  final bool? wheelchairUsesElevator;

  final Duration? car;

  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
    to: TransitPlace.fromJson(asMap(json['to']) ?? const {}),
    defaultDuration: _minutes(json['default']),
    foot: _minutes(json['foot']),
    footRouted: _minutes(json['footRouted']),
    wheelchair: _minutes(json['wheelchair']),
    wheelchairRouted: _minutes(json['wheelchairRouted']),
    wheelchairUsesElevator: asBool(json['wheelchairUsesElevator']),
    car: _minutes(json['car']),
  );

  static Duration? _minutes(Object? value) {
    final minutes = asInt(value);
    return minutes == null ? null : Duration(minutes: minutes);
  }
}
