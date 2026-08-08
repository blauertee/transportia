import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import '../api/endpoints/map_endpoint.dart';
import '../api/transitous_api_exception.dart';
import '../models/transitous/place.dart';
import '../models/transitous/trip_segment.dart';

class TransitousMapServiceException implements Exception {
  TransitousMapServiceException(this.message);
  final String message;

  @override
  String toString() => 'TransitousMapServiceException: $message';
}

class MapStop {
  const MapStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.stopId,
    this.importance,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String? stopId;
  final double? importance;

  LatLng get latLng => LatLng(lat, lon);

  /// Stops without an id are keyed by their coordinate so the map can still
  /// track them across refreshes.
  factory MapStop.fromPlace(TransitPlace place) {
    final stopId = place.stopId;
    final id = (stopId == null || stopId.isEmpty)
        ? 'stop-${place.lat.toStringAsFixed(6)}-${place.lon.toStringAsFixed(6)}'
        : stopId;
    return MapStop(
      id: id,
      name: place.name,
      lat: place.lat,
      lon: place.lon,
      stopId: stopId,
      importance: place.importance,
    );
  }
}

class MapTripSegment {
  const MapTripSegment({
    required this.tripId,
    this.routeShortName,
    this.displayName,
    this.routeColor,
    this.realTime = false,
    this.mode,
    this.fromName,
    this.toName,
    this.fromLat,
    this.fromLon,
    this.toLat,
    this.toLon,
    this.departure,
    this.arrival,
    this.polyline,
  });

  final String tripId;
  final String? routeShortName;
  final String? displayName;
  final String? routeColor;
  final bool realTime;
  final String? mode;
  final String? fromName;
  final String? toName;
  final double? fromLat;
  final double? fromLon;
  final double? toLat;
  final double? toLon;
  final DateTime? departure;
  final DateTime? arrival;
  final String? polyline;

  /// Flattens the API segment for the map layer, which keys vehicles by trip.
  ///
  /// Returns null for a segment without a trip id, since there would be
  /// nothing to track it by.
  static MapTripSegment? fromSegment(TripSegment segment) {
    final trip = segment.primaryTrip;
    if (trip == null || trip.tripId.isEmpty) return null;
    return MapTripSegment(
      tripId: trip.tripId,
      routeShortName: trip.routeShortName,
      displayName: trip.displayName,
      routeColor: segment.routeColor,
      realTime: segment.realTime,
      mode: segment.mode?.wireName,
      fromName: segment.from.name,
      toName: segment.to.name,
      fromLat: segment.from.lat,
      fromLon: segment.from.lon,
      toLat: segment.to.lat,
      toLon: segment.to.lon,
      departure: segment.departure,
      arrival: segment.arrival,
      polyline: segment.polyline,
    );
  }
}

class TransitousMapService {
  static Future<List<MapTripSegment>> fetchTripSegments({
    required double zoom,
    required LatLngBounds bounds,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final box = _Box.of(bounds);
    try {
      final segments = await MapEndpoint.trips(
        zoom: zoom,
        minLat: box.south,
        minLon: box.west,
        maxLat: box.north,
        maxLon: box.east,
        startTime: startTime,
        endTime: endTime,
      );
      return [
        for (final segment in segments)
          if (MapTripSegment.fromSegment(segment) case final trip?) trip,
      ];
    } on TransitousApiException catch (e) {
      throw TransitousMapServiceException(e.message);
    }
  }

  static Future<List<MapStop>> fetchStops({
    required LatLngBounds bounds,
  }) async {
    final box = _Box.of(bounds);
    try {
      final places = await MapEndpoint.stops(
        minLat: box.south,
        minLon: box.west,
        maxLat: box.north,
        maxLon: box.east,
      );
      return [
        for (final place in places)
          if (place.name.isNotEmpty) MapStop.fromPlace(place),
      ];
    } on TransitousApiException catch (e) {
      throw TransitousMapServiceException(e.message);
    }
  }
}

/// Normalised bounding box.
///
/// MapLibre's bounds do not guarantee which corner is which, so the extremes
/// are taken explicitly rather than assumed.
class _Box {
  const _Box({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
  });

  final double south;
  final double north;
  final double west;
  final double east;

  factory _Box.of(LatLngBounds bounds) => _Box(
    south: math.min(bounds.southwest.latitude, bounds.northeast.latitude),
    north: math.max(bounds.southwest.latitude, bounds.northeast.latitude),
    west: math.min(bounds.southwest.longitude, bounds.northeast.longitude),
    east: math.max(bounds.southwest.longitude, bounds.northeast.longitude),
  );
}
