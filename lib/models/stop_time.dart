import 'transitous/place.dart';

class StopTimesResponse {
  final List<StopTime> stopTimes;
  final StopPlace? place;
  final String? previousPageCursor;
  final String? nextPageCursor;

  const StopTimesResponse({
    required this.stopTimes,
    this.place,
    this.previousPageCursor,
    this.nextPageCursor,
  });

  factory StopTimesResponse.fromJson(Map<String, dynamic> json) {
    final rawPlace = json['place'];
    return StopTimesResponse(
      stopTimes: (json['stopTimes'] as List)
          .map((item) => StopTime.fromJson(item as Map<String, dynamic>))
          .toList(),
      place: rawPlace is Map<String, dynamic>
          ? StopPlace.fromJson(rawPlace)
          : null,
      previousPageCursor: json['previousPageCursor'] as String?,
      nextPageCursor: json['nextPageCursor'] as String?,
    );
  }
}

class StopTime {
  final StopPlace place;
  final String mode;
  final bool realTime;
  final String headsign;
  final StopPlace? tripTo;
  final String agencyId;
  final String agencyName;
  final String? agencyUrl;
  final String? routeColor;
  final String? routeTextColor;
  final String tripId;
  final int routeType;
  final String routeShortName;
  final String routeLongName;
  final String displayName;
  final bool cancelled;
  final bool tripCancelled;

  const StopTime({
    required this.place,
    required this.mode,
    required this.realTime,
    required this.headsign,
    this.tripTo,
    required this.agencyId,
    required this.agencyName,
    this.agencyUrl,
    this.routeColor,
    this.routeTextColor,
    required this.tripId,
    required this.routeType,
    required this.routeShortName,
    required this.routeLongName,
    required this.displayName,
    required this.cancelled,
    required this.tripCancelled,
  });

  factory StopTime.fromJson(Map<String, dynamic> json) {
    final routeShortName = json['routeShortName'] as String? ?? '';
    return StopTime(
      place: StopPlace.fromJson(json['place'] as Map<String, dynamic>),
      mode: json['mode'] as String? ?? '',
      realTime: json['realTime'] as bool? ?? false,
      headsign: json['headsign'] as String? ?? '',
      tripTo: json['tripTo'] is Map<String, dynamic>
          ? StopPlace.fromJson(json['tripTo'] as Map<String, dynamic>)
          : null,
      agencyId: json['agencyId'] as String? ?? '',
      agencyName: json['agencyName'] as String? ?? '',
      agencyUrl: json['agencyUrl'] as String?,
      routeColor: json['routeColor'] as String?,
      routeTextColor: json['routeTextColor'] as String?,
      tripId: json['tripId'] as String? ?? '',
      routeType: json['routeType'] as int? ?? 0,
      routeShortName: routeShortName,
      routeLongName: json['routeLongName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? routeShortName,
      cancelled: json['cancelled'] as bool? ?? false,
      tripCancelled: json['tripCancelled'] as bool? ?? false,
    );
  }
}

/// Alias for the shared place model: `/stoptimes` returns the same `Place`
/// object as the itinerary endpoints.
typedef StopPlace = TransitPlace;
