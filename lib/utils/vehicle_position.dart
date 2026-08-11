import '../models/journey_stop.dart';
import 'time_utils.dart';

/// Index value meaning "no stop", used wherever a stop index is optional.
const int kNoStopIndex = -1;

/// Where the vehicle running a trip has got to, expressed against that trip's
/// stop list.
class VehiclePosition {
  const VehiclePosition({
    required this.stopIndex,
    required this.isAtStop,
    required this.isBeforeStart,
    required this.isAfterEnd,
  });

  /// The stop the vehicle is at, or the one it has most recently left when
  /// [isAtStop] is false. [kNoStopIndex] when the times give no answer.
  final int stopIndex;

  /// True when the vehicle is standing at [stopIndex] rather than running
  /// between it and the next stop.
  final bool isAtStop;

  /// The trip has not departed its first stop yet.
  final bool isBeforeStart;

  /// The trip has already reached its last stop.
  final bool isAfterEnd;

  static const VehiclePosition unknown = VehiclePosition(
    stopIndex: kNoStopIndex,
    isAtStop: false,
    isBeforeStart: false,
    isAfterEnd: false,
  );

  bool get isKnown => stopIndex != kNoStopIndex;

  /// Whether a marker for the vehicle belongs on a timeline of [stopCount]
  /// stops.
  bool showsMarker(int stopCount) => stopIndex >= 0 && stopIndex < stopCount;

  /// The last stop already served. Everything up to and including it is drawn
  /// as passed; [kNoStopIndex] means nothing has been served yet.
  int lastServedStopIndex(int stopCount) {
    if (isBeforeStart) return kNoStopIndex;
    if (isAfterEnd) return stopCount == 0 ? kNoStopIndex : stopCount - 1;
    return stopIndex;
  }

  /// The next stop the vehicle will call at, or [kNoStopIndex] when there is
  /// none left to call at.
  int upcomingStopIndex(int stopCount) {
    if (!isKnown || stopCount == 0 || isAfterEnd) return kNoStopIndex;
    if (isBeforeStart) return 0;
    return stopIndex < stopCount - 1 ? stopIndex + 1 : kNoStopIndex;
  }

  /// Whether the vehicle marker should sit *between* [stopIndex] and the stop
  /// after it, rather than on a stop.
  bool sitsBetweenStops(int index, int stopCount) =>
      showsMarker(stopCount) &&
      !isAtStop &&
      index == stopIndex &&
      index < stopCount - 1;
}

/// Reads [stops]' arrival and departure times to work out where the vehicle
/// serving them is right now.
///
/// Times are compared to the minute, because a timetable that says 14:03 and a
/// clock that says 14:03:40 describe the same moment to a rider standing on
/// the platform.
VehiclePosition estimateVehiclePosition(
  List<JourneyStop> stops, {
  DateTime? now,
}) {
  if (stops.isEmpty) return VehiclePosition.unknown;
  final moment = now ?? DateTime.now();

  if (_isBeforeFirstDeparture(stops, moment)) {
    return const VehiclePosition(
      stopIndex: 0,
      isAtStop: true,
      isBeforeStart: true,
      isAfterEnd: false,
    );
  }

  if (_isAfterLastArrival(stops, moment)) return _atTerminus(stops);

  for (int i = 0; i < stops.length; i++) {
    final stop = stops[i];
    if (_isStandingAt(stop, moment)) {
      return VehiclePosition(
        stopIndex: i,
        isAtStop: true,
        isBeforeStart: false,
        isAfterEnd: false,
      );
    }
    if (_isYetToReach(stop, moment)) {
      return VehiclePosition(
        stopIndex: i - 1,
        isAtStop: false,
        isBeforeStart: false,
        isAfterEnd: false,
      );
    }
  }

  return _atTerminus(stops);
}

VehiclePosition _atTerminus(List<JourneyStop> stops) => VehiclePosition(
  stopIndex: stops.length - 1,
  isAtStop: true,
  isBeforeStart: false,
  isAfterEnd: true,
);

bool _isBeforeFirstDeparture(List<JourneyStop> stops, DateTime now) {
  final first = stops.first;
  final departure = first.departure ?? first.arrival;
  return departure != null &&
      !isSameMinute(now, departure) &&
      now.isBefore(departure);
}

bool _isAfterLastArrival(List<JourneyStop> stops, DateTime now) {
  final last = stops.last;
  final arrival = last.arrival ?? last.departure;
  return arrival != null &&
      !isSameMinute(now, arrival) &&
      now.isAfter(arrival);
}

/// The vehicle is at [stop] either because this is its departure minute, or
/// because it is dwelling between arriving and departing.
bool _isStandingAt(JourneyStop stop, DateTime now) {
  final arrival = stop.arrival;
  final departure = stop.departure;
  if (departure != null && isSameMinute(now, departure)) return true;
  return arrival != null &&
      departure != null &&
      now.isAfter(arrival) &&
      now.isBefore(departure);
}

bool _isYetToReach(JourneyStop stop, DateTime now) {
  final next = stop.departure ?? stop.arrival;
  return next != null && now.isBefore(next) && !isSameMinute(now, next);
}
