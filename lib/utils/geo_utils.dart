import 'dart:math' as math;

const double _earthRadiusMeters = 6371000;

double coordinateDistanceInMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);

  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_degreesToRadians(lat1)) *
          math.cos(_degreesToRadians(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusMeters * c;
}

bool areCoordsClose(
  double lat1,
  double lon1,
  double lat2,
  double lon2, {
  double thresholdInMeters = 10,
}) {
  return coordinateDistanceInMeters(lat1, lon1, lat2, lon2) <=
      thresholdInMeters;
}

double _degreesToRadians(double degrees) => degrees * (math.pi / 180.0);

/// A coordinate pair as a fixed-precision string, for identity: cache keys,
/// dedupe buckets, and ids for places the feed never named.
///
/// [decimals] is the whole point of the call and is never incidental — it
/// decides how far apart two coordinates must be to count as different
/// places. The default of six is ~0.1 m, which is exact enough to mean "the
/// same point"; a caller wanting a fuzzy bucket passes fewer.
///
/// Emits no space, so the result stays safe inside a URL or a stored key.
String coordKey(
  double lat,
  double lon, {
  int decimals = 6,
  String separator = ',',
}) =>
    '${lat.toStringAsFixed(decimals)}$separator'
    '${lon.toStringAsFixed(decimals)}';

/// A coordinate pair for a person to read — shown where a place has no name.
///
/// Four decimals is ~10 m, past which the digits are noise on a screen.
String coordLabel(double lat, double lon, {int decimals = 4}) =>
    '${lat.toStringAsFixed(decimals)}, ${lon.toStringAsFixed(decimals)}';

/// Where a map opens before anything better is known — neither the user's
/// location nor a place they picked.
///
/// Prague, at a zoom that shows a city rather than a country. Any populated
/// point would do; what matters is that the map opens somewhere with transit
/// on it rather than in the ocean at 0,0.
const double kFallbackMapLat = 50.087;
const double kFallbackMapLon = 14.420;
const double kFallbackMapZoom = 13.0;
