import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../api/endpoints/plan_endpoint.dart';
import '../api/params/plan_params.dart';
import '../api/query.dart';
import '../api/transitous_api_exception.dart';
import '../constants/prefs_keys.dart';
import '../models/itinerary.dart';
import '../models/itinerary_response.dart';
import '../models/time_selection.dart';

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
    final prefs = SharedPreferencesAsync();
    final walkingSpeedKmh = await prefs.getDouble(
      PrefsKeys.transitWalkingSpeed,
    );
    final transferBuffer = await prefs.getInt(PrefsKeys.transitTransferBuffer);
    final selectedModes = await prefs.getStringList(
      PrefsKeys.transitSelectedModes,
    );

    final params = PlanParams(
      fromPlace: Q.latLonComma(fromLat, fromLon),
      toPlace: Q.latLonComma(toLat, toLon),
      withFares: true,
      useRoutedTransfers: true,
      // The UI stores km/h; the API takes metres per second.
      pedestrianSpeed: walkingSpeedKmh == null ? null : walkingSpeedKmh / 3.6,
      additionalTransferTime: transferBuffer == null || transferBuffer <= 0
          ? null
          : Duration(minutes: transferBuffer),
      transitModes: _modesFrom(selectedModes),
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

  /// Maps the stored mode names onto the enum, dropping any this build does
  /// not know so a stale preference cannot break a search.
  static List<TransitMode> _modesFrom(List<String>? stored) {
    if (stored == null || stored.isEmpty) return const [];
    return [
      for (final name in stored)
        if (TransitMode.fromWire(name) case final mode?) mode,
    ];
  }
}
