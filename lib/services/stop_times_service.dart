import '../api/endpoints/stoptimes_endpoint.dart';
import '../api/transitous_api_exception.dart';
import '../models/stop_time.dart';

class StopTimesServiceException implements Exception {
  StopTimesServiceException(this.message);
  final String message;
  @override
  String toString() => 'StopTimesServiceException: $message';
}

class StopTimesService {
  /// Departures asked for per page — enough to fill a screen and scroll a
  /// little past it, so the next page loads on a deliberate scroll.
  static const int defaultPageSize = 25;

  /// Metres around the stop to gather departures from, so a station's
  /// platforms answer as one place rather than one entry each.
  static const double _stopRadiusMetres = 30;

  static Future<StopTimesResponse> fetchStopTimes({
    required String stopId,
    int n = defaultPageSize,
    String? pageCursor,
    DateTime? startTime,
    bool arriveBy = false,
  }) async {
    try {
      return await StopTimesEndpoint.stopTimes(
        stopId: stopId,
        n: n,
        radius: _stopRadiusMetres,
        pageCursor: pageCursor,
        time: startTime,
        arriveBy: arriveBy ? true : null,
      );
    } on TransitousApiException catch (e) {
      throw StopTimesServiceException(e.message);
    }
  }
}
