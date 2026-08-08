import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/prefs_keys.dart';
import '../models/saved_trip.dart';

/// Storage for connections the user chose to keep.
///
/// Unlike `RecentTripsService` there is no cap and nothing is evicted to
/// make room — a saved trip disappears only when the user removes it, or
/// once it is long enough in the past to be clutter. That is the whole
/// point of saving one.
class SavedTripsService {
  const SavedTripsService._();

  static const String _savedTripsKey = PrefsKeys.savedTrips;

  /// How long a trip stays in the list after it has finished.
  static const Duration _keepPastTripsFor = Duration(days: 30);

  static final ValueNotifier<List<SavedTrip>> savedTripsListenable =
      ValueNotifier<List<SavedTrip>>(<SavedTrip>[]);

  /// All saved trips, soonest departure first.
  static Future<List<SavedTrip>> getSavedTrips() async {
    final trips = await _readTrips();
    savedTripsListenable.value = List.unmodifiable(trips);
    return trips;
  }

  /// Adds [trip], replacing any existing trip with the same id so that
  /// saving the same connection twice does not duplicate it. Keeps a
  /// user-set label from the existing entry.
  static Future<void> saveTrip(SavedTrip trip) async {
    final prefs = SharedPreferencesAsync();
    final trips = await _readTrips(prefs: prefs);

    final existingIndex = trips.indexWhere((t) => t.id == trip.id);
    final toStore = existingIndex == -1
        ? trip
        : trip.withLabel(trips[existingIndex].label ?? trip.label);
    if (existingIndex != -1) {
      trips.removeAt(existingIndex);
    }
    trips.add(toStore);

    await _persist(prefs, trips);
  }

  static Future<void> removeTrip(String id) async {
    final prefs = SharedPreferencesAsync();
    final trips = await _readTrips(prefs: prefs);
    trips.removeWhere((t) => t.id == id);
    await _persist(prefs, trips);
  }

  /// Sets a user-chosen name. Pass null or blank to fall back to the
  /// generated label.
  static Future<void> renameTrip(String id, String? label) async {
    final prefs = SharedPreferencesAsync();
    final trips = await _readTrips(prefs: prefs);
    final index = trips.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final trimmed = label?.trim();
    trips[index] = trips[index].withLabel(
      trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
    await _persist(prefs, trips);
  }

  static Future<bool> isSaved(String id) async {
    final trips = await _readTrips();
    return trips.any((t) => t.id == id);
  }

  /// Drops trips that finished more than [_keepPastTripsFor] ago. Returns
  /// how many were removed.
  static Future<int> pruneExpired() async {
    final prefs = SharedPreferencesAsync();
    final trips = await _readTrips(prefs: prefs);
    final cutoff = DateTime.now().subtract(_keepPastTripsFor);

    final before = trips.length;
    trips.removeWhere((t) => t.arrivalTime.isBefore(cutoff));
    final removed = before - trips.length;

    if (removed > 0) {
      await _persist(prefs, trips);
    }
    return removed;
  }

  static Future<List<SavedTrip>> _readTrips({
    SharedPreferencesAsync? prefs,
  }) async {
    try {
      final storage = prefs ?? SharedPreferencesAsync();
      final encoded = await storage.getString(_savedTripsKey);
      if (encoded == null || encoded.isEmpty) return <SavedTrip>[];

      final decoded = jsonDecode(encoded);
      if (decoded is! List) return <SavedTrip>[];

      final trips = <SavedTrip>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          trips.add(SavedTrip.fromJson(item));
        } catch (_) {
          // Skip entries written by an older or newer schema rather than
          // dropping the whole list.
          continue;
        }
      }

      _sort(trips);
      return trips;
    } catch (_) {
      return <SavedTrip>[];
    }
  }

  static Future<void> _persist(
    SharedPreferencesAsync prefs,
    List<SavedTrip> trips,
  ) async {
    _sort(trips);
    final encoded = jsonEncode(
      trips.map((t) => t.toJson()).toList(growable: false),
    );
    await prefs.setString(_savedTripsKey, encoded);
    savedTripsListenable.value = List.unmodifiable(trips);
  }

  static void _sort(List<SavedTrip> trips) {
    trips.sort((a, b) => a.departureTime.compareTo(b.departureTime));
  }
}
