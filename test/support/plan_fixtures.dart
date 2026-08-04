import 'dart:convert';

/// Builds `/plan` itinerary JSON in the shape the planner actually returns.
///
/// This matters more than it looks. Transitous wraps a journey between two
/// coordinates in walk legs whose outer endpoints are named with the
/// literal placeholders `START` and `END`:
///
/// ```
/// WALK           START                   -> S+U Berlin Hauptbahnhof
/// REGIONAL_RAIL  S+U Berlin Hauptbahnhof -> Flughafen BER
/// WALK           Flughafen BER           -> END
/// ```
///
/// Tests that use a single tidy transit leg never see those placeholders,
/// and so cannot catch code that reads the outermost names directly.
Map<String, dynamic> planItineraryJson({
  required DateTime departure,
  String fromStop = 'S+U Berlin Hauptbahnhof',
  String toStop = 'Flughafen BER',
  String tripId = 'trip-re7',
  String routeName = 'RE7',
  Duration rideLength = const Duration(minutes: 15),
  bool cancelled = false,
  bool withEdgeWalks = true,
}) {
  String at(Duration offset) => departure.add(offset).toUtc().toIso8601String();

  const accessWalk = Duration(minutes: 5);
  final rideStart = withEdgeWalks ? accessWalk : Duration.zero;
  final rideEnd = rideStart + rideLength;
  final egressWalk = withEdgeWalks
      ? rideEnd + const Duration(minutes: 3)
      : rideEnd;

  final ride = {
    'mode': 'REGIONAL_RAIL',
    'startTime': at(rideStart),
    'endTime': at(rideEnd),
    'duration': rideLength.inSeconds,
    'tripId': tripId,
    'routeShortName': routeName,
    'displayName': routeName,
    'realTime': true,
    'cancelled': cancelled,
    'from': {
      'name': fromStop,
      'lat': 52.525,
      'lon': 13.369,
      'stopId': 'stop-from',
      'track': '12',
    },
    'to': {'name': toStop, 'lat': 52.366, 'lon': 13.503, 'stopId': 'stop-to'},
  };

  final legs = <Map<String, dynamic>>[
    if (withEdgeWalks)
      {
        'mode': 'WALK',
        'startTime': at(Duration.zero),
        'endTime': at(accessWalk),
        'duration': accessWalk.inSeconds,
        'distance': 420.0,
        'from': {'name': 'START', 'lat': 52.520, 'lon': 13.405},
        'to': {'name': fromStop, 'lat': 52.525, 'lon': 13.369},
      },
    ride,
    if (withEdgeWalks)
      {
        'mode': 'WALK',
        'startTime': at(rideEnd),
        'endTime': at(egressWalk),
        'duration': 180,
        'distance': 210.0,
        'from': {'name': toStop, 'lat': 52.366, 'lon': 13.503},
        'to': {'name': 'END', 'lat': 52.362, 'lon': 13.510},
      },
  ];

  return jsonDecode(
        jsonEncode({
          'duration': egressWalk.inSeconds,
          'startTime': at(Duration.zero),
          'endTime': at(egressWalk),
          'transfers': 0,
          'legs': legs,
        }),
      )
      as Map<String, dynamic>;
}
