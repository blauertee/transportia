import 'json.dart';
import 'place.dart';

/// A place reachable from the query origin, with how long it takes to get
/// there. Returned by `/one-to-all`.
class ReachablePlace {
  const ReachablePlace({
    required this.place,
    required this.duration,
    required this.transfers,
  });

  final TransitPlace place;

  /// Travel time from the origin.
  final Duration duration;

  /// Number of transfers taken to reach it (the API calls this `k`).
  final int transfers;

  factory ReachablePlace.fromJson(Map<String, dynamic> json) => ReachablePlace(
    place: TransitPlace.fromJson(asMap(json['place']) ?? const {}),
    // /one-to-all reports minutes here, unlike the seconds used elsewhere.
    duration: Duration(minutes: asInt(json['duration']) ?? 0),
    transfers: asInt(json['k']) ?? 0,
  );
}

/// Everything reachable from one origin within a travel-time budget.
class Reachable {
  const Reachable({required this.one, required this.all});

  /// The origin the query started from.
  final TransitPlace one;

  final List<ReachablePlace> all;

  factory Reachable.fromJson(Map<String, dynamic> json) => Reachable(
    one: TransitPlace.fromJson(asMap(json['one']) ?? const {}),
    all: asList(json['all'], ReachablePlace.fromJson),
  );
}

/// Result for a single destination of `/one-to-many`.
///
/// Both fields are absent when no path was found, which is how the API
/// signals unreachable rather than by omitting the entry — the array stays
/// aligned with the requested coordinates.
class StreetDuration {
  const StreetDuration({this.duration, this.distance});

  final Duration? duration;

  /// Metres along the street network, present only when `withDistance` was
  /// requested.
  final double? distance;

  bool get isReachable => duration != null;

  factory StreetDuration.fromJson(Map<String, dynamic> json) => StreetDuration(
    duration: asDuration(json['duration']),
    distance: asDouble(json['distance']),
  );

  static List<StreetDuration> listFromJson(Object? json) =>
      asList(json, StreetDuration.fromJson);
}

/// Result for a single destination of `/one-to-many-intermodal`.
class IntermodalDuration {
  const IntermodalDuration({this.duration, this.transfers});

  final Duration? duration;
  final int? transfers;

  bool get isReachable => duration != null;

  factory IntermodalDuration.fromJson(Map<String, dynamic> json) =>
      IntermodalDuration(
        duration: asDuration(json['duration']),
        transfers: asInt(json['transfers']),
      );
}

/// Street and transit travel times to each requested destination.
///
/// Both lists are ordered to match the `many` parameter of the request.
class OneToManyIntermodal {
  const OneToManyIntermodal({
    required this.streetDurations,
    required this.transitDurations,
  });

  final List<StreetDuration> streetDurations;

  /// Per destination, the Pareto-optimal options trading travel time against
  /// transfers.
  final List<List<IntermodalDuration>> transitDurations;

  factory OneToManyIntermodal.fromJson(Map<String, dynamic> json) {
    final transit = json['transit_durations'];
    return OneToManyIntermodal(
      streetDurations: StreetDuration.listFromJson(json['street_durations']),
      transitDurations: transit is! List
          ? const []
          : List.unmodifiable([
              for (final entry in transit)
                asList(entry, IntermodalDuration.fromJson),
            ]),
    );
  }
}
