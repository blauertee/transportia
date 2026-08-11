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
  static Future<StopTimesResponse> fetchStopTimes({
    required String stopId,
    int n = 25,
    String? pageCursor,
    DateTime? startTime,
    bool arriveBy = false,
  }) async {
    try {
      return await StopTimesEndpoint.stopTimes(
        stopId: stopId,
        n: n,
        radius: 30,
        pageCursor: pageCursor,
        time: startTime,
        arriveBy: arriveBy ? true : null,
      );
    } on TransitousApiException catch (e) {
      throw StopTimesServiceException(e.message);
    }
  }
}
