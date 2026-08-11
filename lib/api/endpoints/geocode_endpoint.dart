import '../../models/transitous/enums.dart';
import '../../models/transitous/match.dart';
import '../query.dart';
import '../transitous_client.dart';
import '../transitous_endpoint.dart';

/// `/geocode` and `/reverse-geocode`.
class GeocodeEndpoint {
  const GeocodeEndpoint._();

  /// Searches places by name.
  static Future<List<Match>> geocode({
    required String text,
    List<String> languages = const [],
    LocationType? type,
    List<TransitMode> modes = const [],
    double? placeLat,
    double? placeLon,
    double? placeBias,
    int? numResults,
    double? minLat,
    double? minLon,
    double? maxLat,
    double? maxLon,
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.geocode,
      {
        'text': text,
        'language': Q.csv(languages),
        'type': type?.wireName,
        'mode': Q.csv(modes.map((m) => m.wireName)),
        // Bias results towards this coordinate.
        'place': placeLat == null || placeLon == null
            ? null
            : Q.latLonComma(placeLat, placeLon),
        // How strongly `place` outweighs relevance.
        'placeBias': Q.number(placeBias),
        'numResults': Q.integer(numResults),
        // Restrict to a bounding box, unlike `place` which only biases.
        'min': minLat == null || minLon == null
            ? null
            : Q.latLonComma(minLat, minLon),
        'max': maxLat == null || maxLon == null
            ? null
            : Q.latLonComma(maxLat, maxLon),
      },
      _parseMatches,
    );
  }

  /// Finds places at a coordinate, nearest first.
  static Future<List<Match>> reverseGeocode({
    required double lat,
    required double lon,
    LocationType? type,
    int? numResults,
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance)
        .get(TransitousEndpoint.reverseGeocode, {
          'place': Q.latLonComma(lat, lon),
          'type': type?.wireName,
          'numResults': Q.integer(numResults),
        }, _parseMatches);
  }

  static List<Match> _parseMatches(dynamic json) {
    if (json is! List) return const [];
    return [
      for (final entry in json)
        if (entry is Map<String, dynamic>) Match.fromJson(entry),
    ];
  }
}
