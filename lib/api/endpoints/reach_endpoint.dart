import '../../models/transitous/enums.dart';
import '../../models/transitous/reachability.dart';
import '../params/plan_params.dart';
import '../query.dart';
import '../transitous_client.dart';
import '../transitous_endpoint.dart';

/// Reachability endpoints: `/one-to-many`, `/one-to-all` and the experimental
/// `/one-to-many-intermodal`.
///
/// Mind the coordinate format. The two one-to-many endpoints take `lat;lon`
/// and reject `lat,lon`; `/one-to-all` is the other way round. This is the
/// only place in the API where that distinction exists.
class ReachEndpoint {
  const ReachEndpoint._();

  /// Street travel times from one point to many, or the reverse when
  /// [arriveBy] is set.
  ///
  /// The result is positional: entry `n` corresponds to destination `n`, and
  /// an unreachable destination still occupies its slot. The number of
  /// destinations is capped by `ServerConfig.maxOneToManySize`.
  static Future<List<StreetDuration>> oneToMany({
    required double oneLat,
    required double oneLon,
    required List<({double lat, double lon})> many,
    required TransitMode mode,
    required Duration max,
    required double maxMatchingDistance,
    // Required by the server, unlike everywhere else it appears: omitting it
    // fails the request with "missing parameter".
    required bool arriveBy,
    bool? withDistance,
    ElevationCosts? elevationCosts,
    VehicleProfile vehicle = const VehicleProfile(),
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance)
        .get(TransitousEndpoint.oneToMany, {
          'one': Q.latLonSemicolon(oneLat, oneLon),
          'many': Q.csv(many.map((p) => Q.latLonSemicolon(p.lat, p.lon))),
          'mode': mode.wireName,
          'max': Q.seconds(max),
          'maxMatchingDistance': Q.number(maxMatchingDistance),
          'arriveBy': Q.boolean(arriveBy),
          'withDistance': Q.boolean(withDistance),
          'elevationCosts': elevationCosts?.wireName,
          ...vehicle.toQuery(),
        }, StreetDuration.listFromJson);
  }

  /// Everywhere reachable from one point within a travel-time budget, using
  /// transit.
  ///
  /// [maxTravelTime] is capped by `ServerConfig.maxOneToAllTravelTime`.
  static Future<Reachable> oneToAll({
    required double oneLat,
    required double oneLon,
    required Duration maxTravelTime,
    DateTime? time,
    bool? arriveBy,
    int? maxTransfers,
    Duration? minTransferTime,
    Duration? additionalTransferTime,
    double? transferTimeFactor,
    double? maxMatchingDistance,
    bool? useRoutedTransfers,
    PedestrianProfile? pedestrianProfile,
    double? pedestrianSpeed,
    double? cyclingSpeed,
    ElevationCosts? elevationCosts,
    List<TransitMode> transitModes = const [],
    List<TransitMode> preTransitModes = const [],
    List<TransitMode> postTransitModes = const [],
    bool? requireBikeTransport,
    bool? requireCarTransport,
    bool? noCompulsoryReservation,
    Duration? maxPreTransitTime,
    Duration? maxPostTransitTime,
    VehicleProfile vehicle = const VehicleProfile(),
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.oneToAll,
      {
        // Comma form here, unlike the one-to-many endpoints above.
        'one': Q.latLonComma(oneLat, oneLon),
        'maxTravelTime': Q.minutes(maxTravelTime),
        'time': Q.dateTime(time),
        'arriveBy': Q.boolean(arriveBy),
        'maxTransfers': Q.integer(maxTransfers),
        'minTransferTime': Q.minutes(minTransferTime),
        'additionalTransferTime': Q.minutes(additionalTransferTime),
        'transferTimeFactor': Q.number(transferTimeFactor),
        'maxMatchingDistance': Q.number(maxMatchingDistance),
        'useRoutedTransfers': Q.boolean(useRoutedTransfers),
        'pedestrianProfile': pedestrianProfile?.wireName,
        'pedestrianSpeed': Q.number(pedestrianSpeed),
        'cyclingSpeed': Q.number(cyclingSpeed),
        'elevationCosts': elevationCosts?.wireName,
        'transitModes': Q.csv(transitModes.map((m) => m.wireName)),
        'preTransitModes': Q.csv(preTransitModes.map((m) => m.wireName)),
        'postTransitModes': Q.csv(postTransitModes.map((m) => m.wireName)),
        'requireBikeTransport': Q.boolean(requireBikeTransport),
        'requireCarTransport': Q.boolean(requireCarTransport),
        'noCompulsoryReservation': Q.boolean(noCompulsoryReservation),
        'maxPreTransitTime': Q.seconds(maxPreTransitTime),
        'maxPostTransitTime': Q.seconds(maxPostTransitTime),
        ...vehicle.toQuery(),
      },
      (json) => Reachable.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Street and transit travel times from one point to many.
  ///
  /// Experimental upstream: the response may change without a version bump.
  static Future<OneToManyIntermodal> oneToManyIntermodal({
    required double oneLat,
    required double oneLon,
    required List<({double lat, double lon})> many,
    required Duration maxTravelTime,
    DateTime? time,
    bool? arriveBy,
    double? maxMatchingDistance,
    int? maxTransfers,
    Duration? minTransferTime,
    Duration? additionalTransferTime,
    double? transferTimeFactor,
    bool? useRoutedTransfers,
    PedestrianProfile? pedestrianProfile,
    double? pedestrianSpeed,
    double? cyclingSpeed,
    ElevationCosts? elevationCosts,
    List<TransitMode> transitModes = const [],
    List<TransitMode> preTransitModes = const [],
    List<TransitMode> postTransitModes = const [],
    TransitMode? directMode,
    Duration? maxPreTransitTime,
    Duration? maxPostTransitTime,
    Duration? maxDirectTime,
    bool? withDistance,
    bool? requireBikeTransport,
    bool? requireCarTransport,
    bool? noCompulsoryReservation,
    VehicleProfile vehicle = const VehicleProfile(),
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.oneToManyIntermodal,
      {
        'one': Q.latLonSemicolon(oneLat, oneLon),
        'many': Q.csv(many.map((p) => Q.latLonSemicolon(p.lat, p.lon))),
        'time': Q.dateTime(time),
        'maxTravelTime': Q.minutes(maxTravelTime),
        'arriveBy': Q.boolean(arriveBy),
        'maxMatchingDistance': Q.number(maxMatchingDistance),
        'maxTransfers': Q.integer(maxTransfers),
        'minTransferTime': Q.minutes(minTransferTime),
        'additionalTransferTime': Q.minutes(additionalTransferTime),
        'transferTimeFactor': Q.number(transferTimeFactor),
        'useRoutedTransfers': Q.boolean(useRoutedTransfers),
        'pedestrianProfile': pedestrianProfile?.wireName,
        'pedestrianSpeed': Q.number(pedestrianSpeed),
        'cyclingSpeed': Q.number(cyclingSpeed),
        'elevationCosts': elevationCosts?.wireName,
        'transitModes': Q.csv(transitModes.map((m) => m.wireName)),
        'preTransitModes': Q.csv(preTransitModes.map((m) => m.wireName)),
        'postTransitModes': Q.csv(postTransitModes.map((m) => m.wireName)),
        // Singular here, unlike /plan's directModes list.
        'directMode': directMode?.wireName,
        'maxPreTransitTime': Q.seconds(maxPreTransitTime),
        'maxPostTransitTime': Q.seconds(maxPostTransitTime),
        'maxDirectTime': Q.seconds(maxDirectTime),
        'withDistance': Q.boolean(withDistance),
        'requireBikeTransport': Q.boolean(requireBikeTransport),
        'requireCarTransport': Q.boolean(requireCarTransport),
        'noCompulsoryReservation': Q.boolean(noCompulsoryReservation),
        ...vehicle.toQuery(),
      },
      (json) => OneToManyIntermodal.fromJson(json as Map<String, dynamic>),
    );
  }
}
