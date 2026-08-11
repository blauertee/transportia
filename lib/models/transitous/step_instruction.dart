import '../itinerary.dart' show EncodedPolyline;
import 'enums.dart';
import 'json.dart';

/// One turn-by-turn instruction within a walking, cycling or driving leg.
///
/// Only returned when the request asks for detailed legs; a leg without
/// street routing has no steps.
class StepInstruction {
  const StepInstruction({
    required this.relativeDirection,
    required this.distance,
    required this.streetName,
    this.fromLevel,
    this.toLevel,
    this.osmWay,
    this.fromOsmNode,
    this.toOsmNode,
    this.polyline,
    this.exit,
    this.stayOn = false,
    this.area = false,
    this.toll = false,
    this.accessRestriction,
    this.elevationUp,
    this.elevationDown,
  });

  /// Turn to take. Null when the server sends a direction this build does not
  /// know; the step is still usable for its distance and street name.
  final StepDirection? relativeDirection;

  /// Distance of this step in metres.
  final double distance;

  final String streetName;

  /// Indoor levels this step starts and ends on.
  final double? fromLevel;
  final double? toLevel;

  /// OpenStreetMap identifiers, useful for debugging a route on the map.
  final int? osmWay;
  final int? fromOsmNode;
  final int? toOsmNode;

  final EncodedPolyline? polyline;

  /// Exit number, for roundabouts and motorway junctions.
  final String? exit;

  /// True when the step continues on the same street rather than turning onto
  /// a new one.
  final bool stayOn;

  /// True when the step crosses an open area rather than following a way.
  final bool area;

  final bool toll;

  /// Access restriction that applies to this step, e.g. `destination`.
  final String? accessRestriction;

  /// Cumulative climb and descent in metres, when elevation data is available.
  final int? elevationUp;
  final int? elevationDown;

  factory StepInstruction.fromJson(Map<String, dynamic> json) {
    final polyline = asMap(json['polyline']);
    return StepInstruction(
      relativeDirection: StepDirection.fromWire(json['relativeDirection']),
      distance: asDouble(json['distance']) ?? 0.0,
      streetName: asString(json['streetName']) ?? '',
      fromLevel: asDouble(json['fromLevel']),
      toLevel: asDouble(json['toLevel']),
      osmWay: asInt(json['osmWay']),
      fromOsmNode: asInt(json['fromOsmNode']),
      toOsmNode: asInt(json['toOsmNode']),
      polyline: polyline == null || polyline.isEmpty
          ? null
          : EncodedPolyline.fromJson(polyline),
      exit: asString(json['exit']),
      stayOn: asBool(json['stayOn']) ?? false,
      area: asBool(json['area']) ?? false,
      toll: asBool(json['toll']) ?? false,
      accessRestriction: asString(json['accessRestriction']),
      elevationUp: asInt(json['elevationUp']),
      elevationDown: asInt(json['elevationDown']),
    );
  }
}
