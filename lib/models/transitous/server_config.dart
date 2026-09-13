import 'json.dart';

/// What the connected MOTIS instance supports and how far it will let a
/// request go.
///
/// Worth reading before showing routing controls: a self-hosted instance
/// without elevation data or street routing cannot honour those options, and
/// the limits below are hard caps the server enforces regardless of what the
/// app asks for.
class ServerConfig {
  const ServerConfig({
    required this.motisVersion,
    required this.hasElevation,
    required this.hasRoutedTransfers,
    required this.hasStreetRouting,
    required this.maxOneToManySize,
    required this.maxOneToAllTravelTime,
    required this.maxPrePostTransitTime,
    required this.maxDirectTime,
    required this.shapesDebugEnabled,
  });

  final String motisVersion;

  /// Whether elevation costs can be applied to street legs.
  final bool hasElevation;

  /// Whether transfers can be routed over the street network rather than
  /// taken from the timetable's transfer times.
  final bool hasRoutedTransfers;

  final bool hasStreetRouting;

  /// Most destinations `/one-to-many` accepts in one request.
  final int maxOneToManySize;

  /// Cap on `/one-to-all`'s `maxTravelTime`.
  final Duration maxOneToAllTravelTime;

  /// Cap on `maxPreTransitTime` and `maxPostTransitTime`.
  final Duration maxPrePostTransitTime;

  /// Cap on `maxDirectTime`.
  final Duration maxDirectTime;

  final bool shapesDebugEnabled;

  /// Transitous's values as of MOTIS v2.11.1, used until `/map/initial`
  /// answers so the UI has sane bounds on first paint.
  static const ServerConfig fallback = ServerConfig(
    motisVersion: 'unknown',
    hasElevation: true,
    hasRoutedTransfers: true,
    hasStreetRouting: true,
    maxOneToManySize: 128,
    maxOneToAllTravelTime: Duration(days: 2),
    maxPrePostTransitTime: Duration(hours: 2),
    maxDirectTime: Duration(hours: 6),
    shapesDebugEnabled: false,
  );

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
    motisVersion: asString(json['motisVersion']) ?? 'unknown',
    hasElevation: asBool(json['hasElevation']) ?? false,
    hasRoutedTransfers: asBool(json['hasRoutedTransfers']) ?? false,
    hasStreetRouting: asBool(json['hasStreetRouting']) ?? false,
    maxOneToManySize: asInt(json['maxOneToManySize']) ?? 0,
    // /one-to-all's limit is in minutes; the pre/post and direct limits are
    // in seconds.
    maxOneToAllTravelTime: Duration(
      minutes: asInt(json['maxOneToAllTravelTimeLimit']) ?? 0,
    ),
    maxPrePostTransitTime: Duration(
      seconds: asInt(json['maxPrePostTransitTimeLimit']) ?? 0,
    ),
    maxDirectTime: Duration(seconds: asInt(json['maxDirectTimeLimit']) ?? 0),
    shapesDebugEnabled: asBool(json['shapesDebugEnabled']) ?? false,
  );
}

/// Response of `/map/initial`: where to centre the map on first load, plus
/// the server's capabilities.
class InitialMapView {
  const InitialMapView({
    required this.lat,
    required this.lon,
    required this.zoom,
    required this.serverConfig,
  });

  final double lat;
  final double lon;
  final double zoom;
  final ServerConfig serverConfig;

  factory InitialMapView.fromJson(Map<String, dynamic> json) => InitialMapView(
    lat: asDouble(json['lat']) ?? 0.0,
    lon: asDouble(json['lon']) ?? 0.0,
    zoom: asDouble(json['zoom']) ?? 4.0,
    serverConfig: ServerConfig.fromJson(
      asMap(json['serverConfig']) ?? const {},
    ),
  );
}

/// Response of `/health`: which optional data feeds are live.
class HealthStatus {
  const HealthStatus({required this.realtime, required this.gbfs});

  /// Real-time timetable updates are being ingested.
  final bool realtime;

  /// Vehicle-sharing feeds are being ingested.
  final bool gbfs;

  factory HealthStatus.fromJson(Map<String, dynamic> json) => HealthStatus(
    realtime: asBool(json['rt']) ?? false,
    gbfs: asBool(json['gbfs']) ?? false,
  );
}
