import 'dart:developer' as developer;

import '../api/endpoints/plan_endpoint.dart';
import '../api/query.dart';
import '../api/transitous_api_exception.dart';
import '../models/itinerary.dart';
import '../models/itinerary_response.dart';
import '../models/time_selection.dart';
import 'routing_options_service.dart';

class RoutingService {
  static Future<List<Itinerary>> findRoutes({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    TimeSelection? timeSelection,
  }) async {
    final response = await findRoutesPaginated(
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      timeSelection: timeSelection,
    );
    return response.itineraries;
  }

  static Future<ItineraryResponse> findRoutesPaginated({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    TimeSelection? timeSelection,
    String? pageCursor,
  }) async {
    final options = await RoutingOptionsService.load();

    final params = options.toPlanParams(
      fromPlace: Q.latLonComma(fromLat, fromLon),
      toPlace: Q.latLonComma(toLat, toLon),
      pageCursor: pageCursor,
      time: timeSelection == null || timeSelection.isNow
          ? null
          : timeSelection.dateTime,
      arriveBy: timeSelection != null && !timeSelection.isNow
          ? timeSelection.isArriveBy
          : null,
    );

    try {
      return await PlanEndpoint.plan(params);
    } on TransitousApiException catch (e, stackTrace) {
      developer.log(
        'Failed to load routes',
        name: 'RoutingService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
