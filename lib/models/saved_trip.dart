import 'itinerary.dart';
import 'time_selection.dart';
import '../utils/time_utils.dart';

/// A connection the user deliberately kept, as opposed to the
/// origin/destination pairs `RecentTripsService` records automatically.
///
/// It holds two things, and needs both:
///
/// * the **snapshot** — the raw planner output for the itinerary that was
///   chosen, so the exact departure can be shown again;
/// * the **intent** — where the user was going and when, so the app can
///   re-plan when the snapshot no longer holds (cancelled leg, timetable
///   change, or simply a departure too far out for the real-time feed).
class SavedTrip {
  SavedTrip({
    required this.id,
    required this.fromName,
    required this.fromLat,
    required this.fromLon,
    required this.toName,
    required this.toLat,
    required this.toLon,
    required this.timeSelection,
    required this.departureTime,
    required this.arrivalTime,
    required this.savedAt,
    required this.itineraryJson,
    this.label,
    this.fromStopId,
    this.toStopId,
    this.isDirect = false,
  });

  final String id;
  final String? label;

  final String fromName;
  final double fromLat;
  final double fromLon;
  final String? fromStopId;

  final String toName;
  final double toLat;
  final double toLon;
  final String? toStopId;

  /// What the user searched for. Used to re-plan when the snapshot dies.
  final TimeSelection timeSelection;

  /// Denormalised from the snapshot so lists can sort and group without
  /// parsing every stored itinerary.
  final DateTime departureTime;
  final DateTime arrivalTime;

  final DateTime savedAt;
  final bool isDirect;

  /// The raw planner output, straight from `Itinerary.sourceJson`.
  final Map<String, dynamic> itineraryJson;

  Itinerary? _itinerary;

  /// The stored connection. Parsed on first access and cached, since list
  /// views only need [departureTime] and the names.
  Itinerary get itinerary =>
      _itinerary ??= Itinerary.fromJson(itineraryJson, isDirect: isDirect);

  bool get isPast => arrivalTime.isBefore(DateTime.now());

  String get displayLabel =>
      label?.trim().isNotEmpty == true ? label!.trim() : defaultLabel;

  String get defaultLabel =>
      '$fromName → $toName · ${formatRelativeDay(departureTime)} '
      '${formatTime(departureTime)}';

  /// Identity of a saved connection: the same departure of the same trip
  /// between the same two points. Re-saving one replaces it rather than
  /// piling up duplicates.
  static String buildId({
    required Itinerary itinerary,
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) {
    final firstTripId = itinerary.legs
        .map((leg) => leg.tripId)
        .whereType<String>()
        .where((tripId) => tripId.isNotEmpty)
        .firstOrNull;
    final from = '${fromLat.toStringAsFixed(4)},${fromLon.toStringAsFixed(4)}';
    final to = '${toLat.toStringAsFixed(4)},${toLon.toStringAsFixed(4)}';
    final departure = itinerary.startTime.toUtc().toIso8601String();
    return '$from>$to@$departure#${firstTripId ?? 'walk'}';
  }

  /// Builds a saved trip from a chosen [itinerary].
  ///
  /// The itinerary must have come from the API — [Itinerary.sourceJson] is
  /// what gets persisted, so an itinerary assembled in code cannot be saved.
  ///
  /// The endpoints and [timeSelection] default to the itinerary's own, which
  /// is usually what you want: the origin the user typed may have been "My
  /// Location", and that means nothing when the trip is opened again from
  /// somewhere else, whereas the first leg says where the journey actually
  /// starts.
  factory SavedTrip.fromItinerary({
    required Itinerary itinerary,
    String? fromName,
    double? fromLat,
    double? fromLon,
    String? toName,
    double? toLat,
    double? toLon,
    TimeSelection? timeSelection,
    String? label,
    DateTime? savedAt,
  }) {
    final json = itinerary.sourceJson;
    if (json == null) {
      throw ArgumentError(
        'Only itineraries parsed from the planner can be saved.',
      );
    }

    // Read the schedule back out of the snapshot rather than off the
    // in-memory itinerary, which may already carry real-time offsets.
    final snapshot = Itinerary.fromJson(json, isDirect: itinerary.isDirect);
    final firstLeg = snapshot.legs.firstOrNull;
    final lastLeg = snapshot.legs.lastOrNull;

    if (firstLeg == null || lastLeg == null) {
      throw ArgumentError('An itinerary without legs cannot be saved.');
    }

    final resolvedFromLat = fromLat ?? firstLeg.fromLat;
    final resolvedFromLon = fromLon ?? firstLeg.fromLon;
    final resolvedToLat = toLat ?? lastLeg.toLat;
    final resolvedToLon = toLon ?? lastLeg.toLon;

    return SavedTrip(
      id: buildId(
        itinerary: snapshot,
        fromLat: resolvedFromLat,
        fromLon: resolvedFromLon,
        toLat: resolvedToLat,
        toLon: resolvedToLon,
      ),
      label: label,
      fromName: fromName ?? firstLeg.fromName,
      fromLat: resolvedFromLat,
      fromLon: resolvedFromLon,
      fromStopId: firstLeg.fromStopId,
      toName: toName ?? lastLeg.toName,
      toLat: resolvedToLat,
      toLon: resolvedToLon,
      toStopId: lastLeg.toStopId,
      timeSelection:
          timeSelection ??
          TimeSelection(dateTime: snapshot.startTime, isArriveBy: false),
      departureTime: snapshot.startTime,
      arrivalTime: snapshot.endTime,
      savedAt: savedAt ?? DateTime.now(),
      isDirect: itinerary.isDirect,
      itineraryJson: json,
    );
  }

  /// Returns a copy carrying [label] as the user-set name. Pass null to
  /// clear it and fall back to [defaultLabel].
  ///
  /// Deliberately not a general `copyWith`: the label is the only mutable
  /// part of a saved trip, and a nullable `copyWith` parameter cannot tell
  /// "leave it alone" from "clear it".
  SavedTrip withLabel(String? label) {
    return SavedTrip(
      id: id,
      label: label,
      fromName: fromName,
      fromLat: fromLat,
      fromLon: fromLon,
      fromStopId: fromStopId,
      toName: toName,
      toLat: toLat,
      toLon: toLon,
      toStopId: toStopId,
      timeSelection: timeSelection,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      savedAt: savedAt,
      isDirect: isDirect,
      itineraryJson: itineraryJson,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (label != null) 'label': label,
    'fromName': fromName,
    'fromLat': fromLat,
    'fromLon': fromLon,
    if (fromStopId != null) 'fromStopId': fromStopId,
    'toName': toName,
    'toLat': toLat,
    'toLon': toLon,
    if (toStopId != null) 'toStopId': toStopId,
    'timeSelection': timeSelection.toJson(),
    'departureTime': departureTime.toIso8601String(),
    'arrivalTime': arrivalTime.toIso8601String(),
    'savedAt': savedAt.toIso8601String(),
    'isDirect': isDirect,
    'itinerary': itineraryJson,
  };

  factory SavedTrip.fromJson(Map<String, dynamic> json) {
    return SavedTrip(
      id: json['id'] as String,
      label: json['label'] as String?,
      fromName: json['fromName'] as String,
      fromLat: (json['fromLat'] as num).toDouble(),
      fromLon: (json['fromLon'] as num).toDouble(),
      fromStopId: json['fromStopId'] as String?,
      toName: json['toName'] as String,
      toLat: (json['toLat'] as num).toDouble(),
      toLon: (json['toLon'] as num).toDouble(),
      toStopId: json['toStopId'] as String?,
      timeSelection: TimeSelection.fromJson(
        json['timeSelection'] as Map<String, dynamic>,
      ),
      departureTime: DateTime.parse(json['departureTime'] as String),
      arrivalTime: DateTime.parse(json['arrivalTime'] as String),
      savedAt: DateTime.parse(json['savedAt'] as String),
      isDirect: json['isDirect'] as bool? ?? false,
      itineraryJson: json['itinerary'] as Map<String, dynamic>,
    );
  }
}
