import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/prefs_keys.dart';

class FavoritePlace {
  final String id;

  /// What the place is actually called, as searched for.
  ///
  /// Kept even when the place is renamed, so clearing the alias restores it
  /// rather than leaving the place nameless.
  final String name;

  /// The rider's name for it — "Home", "Work". Null means [name] stands.
  final String? label;

  final double lat;
  final double lon;
  final DateTime addedAt;
  final String iconName;

  const FavoritePlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.addedAt,
    this.label,
    this.iconName = 'mapPin',
  });

  /// What to show. The alias when there is one, the searched name otherwise.
  String get displayName => (label?.trim().isNotEmpty ?? false) ? label! : name;

  /// True when the alias says something the searched name does not, so a row
  /// can show both without repeating itself.
  bool get hasAlias => displayName != name;

  FavoritePlace copyWith({
    String? id,
    String? name,
    String? label,
    bool clearLabel = false,
    double? lat,
    double? lon,
    DateTime? addedAt,
    String? iconName,
  }) {
    return FavoritePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      label: clearLabel ? null : (label ?? this.label),
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      addedAt: addedAt ?? this.addedAt,
      iconName: iconName ?? this.iconName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'lat': lat,
      'lon': lon,
      'addedAt': addedAt.toIso8601String(),
      'iconName': iconName,
    };
  }

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      id: json['id'] as String,
      name: json['name'] as String,
      label: json['label'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      addedAt: DateTime.parse(json['addedAt'] as String),
      iconName: json['iconName'] as String? ?? 'mapPin',
    );
  }
}

class FavoritesService {
  static const String _favoritesKey = PrefsKeys.favoritePlaces;
  static final ValueNotifier<List<FavoritePlace>> favoritesListenable =
      ValueNotifier<List<FavoritePlace>>(<FavoritePlace>[]);

  static Future<List<FavoritePlace>> getFavorites() async {
    final favourites = await _readFavorites();
    favoritesListenable.value = List.unmodifiable(favourites);
    return favourites;
  }

  static Future<void> saveFavorite(FavoritePlace place) async {
    try {
      final prefs = SharedPreferencesAsync();
      final favorites = await _readFavorites(prefs: prefs);
      final exists = favorites.any((f) => f.id == place.id);
      if (exists) return;

      favorites.insert(0, place);
      await _persistFavorites(prefs, favorites);
      favoritesListenable.value = List.unmodifiable(favorites);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> removeFavorite(String id) async {
    try {
      final prefs = SharedPreferencesAsync();
      final favorites = await _readFavorites(prefs: prefs);
      favorites.removeWhere((f) => f.id == id);
      await _persistFavorites(prefs, favorites);
      favoritesListenable.value = List.unmodifiable(favorites);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> updateFavorite(FavoritePlace updatedPlace) async {
    try {
      final prefs = SharedPreferencesAsync();
      final favorites = await _readFavorites(prefs: prefs);
      final index = favorites.indexWhere((f) => f.id == updatedPlace.id);
      if (index != -1) {
        favorites[index] = updatedPlace;
        await _persistFavorites(prefs, favorites);
        favoritesListenable.value = List.unmodifiable(favorites);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> reorderFavorites(List<FavoritePlace> reordered) async {
    try {
      final prefs = SharedPreferencesAsync();
      final favorites = List<FavoritePlace>.from(reordered);
      await _persistFavorites(prefs, favorites);
      favoritesListenable.value = List.unmodifiable(favorites);
    } catch (e) {
      rethrow;
    }
  }

  /// The favourite at these coordinates, if there is one.
  ///
  /// Matched on position rather than id: a place hearted from a search and the
  /// same place reached from a deep link carry different ids, and a rider
  /// would not call them two places. Five decimals is about a metre.
  static FavoritePlace? findAt(double lat, double lon) {
    final key = _coordinateKey(lat, lon);
    for (final favourite in favoritesListenable.value) {
      if (_coordinateKey(favourite.lat, favourite.lon) == key) return favourite;
    }
    return null;
  }

  static String _coordinateKey(double lat, double lon) =>
      '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';

  /// Adds a place, or removes it when it is already there.
  ///
  /// Returns the favourite that was added, or null when one was removed, so
  /// the caller can say which happened.
  static Future<FavoritePlace?> toggleAt({
    required String name,
    required double lat,
    required double lon,
  }) async {
    final existing = findAt(lat, lon);
    if (existing != null) {
      await removeFavorite(existing.id);
      return null;
    }
    final place = FavoritePlace(
      id: 'fav_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      lat: lat,
      lon: lon,
      addedAt: DateTime.now(),
    );
    await saveFavorite(place);
    return place;
  }

  static Future<bool> isFavorite(String id) async {
    try {
      final favorites = await _readFavorites();
      return favorites.any((f) => f.id == id);
    } catch (e) {
      return false;
    }
  }

  static Future<List<FavoritePlace>> _readFavorites({
    SharedPreferencesAsync? prefs,
  }) async {
    try {
      final storage = prefs ?? SharedPreferencesAsync();
      final String? jsonString = await storage.getString(_favoritesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return <FavoritePlace>[];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) => FavoritePlace.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return <FavoritePlace>[];
    }
  }

  static Future<void> _persistFavorites(
    SharedPreferencesAsync prefs,
    List<FavoritePlace> favorites,
  ) async {
    final encoded = json.encode(
      favorites.map((f) => f.toJson()).toList(growable: false),
    );
    await prefs.setString(_favoritesKey, encoded);
  }
}
