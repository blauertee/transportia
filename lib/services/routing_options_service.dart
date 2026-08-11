import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/prefs_keys.dart';
import '../models/routing_options.dart';
import '../models/transitous/enums.dart';

/// Stores the user's routing preferences.
///
/// One JSON blob rather than a key per option, so adding an option does not
/// mean adding a preference key and a migration.
class RoutingOptionsService {
  const RoutingOptionsService._();

  /// Current options. Screens that build a query should read this rather than
  /// the preferences directly.
  static final ValueNotifier<RoutingOptions> optionsListenable =
      ValueNotifier<RoutingOptions>(RoutingOptions.defaults);

  static Future<RoutingOptions>? _inFlight;
  static bool _loaded = false;

  /// Loads once and caches. Concurrent callers share one read.
  static Future<RoutingOptions> load() async {
    if (_loaded) return optionsListenable.value;
    return (_inFlight ??= _load());
  }

  static Future<RoutingOptions> _load() async {
    try {
      final prefs = SharedPreferencesAsync();
      final stored = await prefs.getString(PrefsKeys.routingOptions);

      if (stored != null && stored.isNotEmpty) {
        optionsListenable.value = _decode(stored);
      } else {
        // First run after the upgrade: carry the three separate settings the
        // Transit options screen used to write, so nobody silently loses them.
        final migrated = await _migrateLegacy(prefs);
        optionsListenable.value = migrated;
        if (migrated != RoutingOptions.defaults) {
          await _write(prefs, migrated);
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Could not read routing options, using defaults',
        name: 'RoutingOptionsService',
        error: e,
        stackTrace: stackTrace,
      );
      optionsListenable.value = RoutingOptions.defaults;
    } finally {
      _loaded = true;
      _inFlight = null;
    }
    return optionsListenable.value;
  }

  static Future<void> save(RoutingOptions options) async {
    optionsListenable.value = options;
    _loaded = true;
    await _write(SharedPreferencesAsync(), options);
  }

  /// Restores every option to the server's defaults.
  static Future<void> reset() => save(RoutingOptions.defaults);

  /// Forgets the cache so the next [load] reads from storage again. For tests
  /// and for switching backends.
  @visibleForTesting
  static void invalidate() {
    _loaded = false;
    _inFlight = null;
    optionsListenable.value = RoutingOptions.defaults;
  }

  static Future<void> _write(
    SharedPreferencesAsync prefs,
    RoutingOptions options,
  ) async {
    await prefs.setString(
      PrefsKeys.routingOptions,
      json.encode(options.toJson()),
    );
  }

  static RoutingOptions _decode(String stored) {
    final decoded = json.decode(stored);
    if (decoded is! Map<String, dynamic>) return RoutingOptions.defaults;
    return RoutingOptions.fromJson(decoded);
  }

  /// Reads the pre-blob preference keys.
  ///
  /// The old keys are left in place: they are small, and removing them would
  /// lose the settings for anyone who downgrades.
  static Future<RoutingOptions> _migrateLegacy(
    SharedPreferencesAsync prefs,
  ) async {
    final speed = await prefs.getDouble(PrefsKeys.transitWalkingSpeed);
    final buffer = await prefs.getInt(PrefsKeys.transitTransferBuffer);
    final modes = await prefs.getStringList(PrefsKeys.transitSelectedModes);

    if (speed == null && buffer == null && modes == null) {
      return RoutingOptions.defaults;
    }

    return RoutingOptions.defaults.copyWith(
      walkingSpeedKmh: speed,
      additionalTransferTime: buffer == null ? null : Duration(minutes: buffer),
      transitModes: modes == null ? null : _modesFrom(modes),
    );
  }

  /// The old screen wrote out every mode it knew when nothing was
  /// deselected. Sending that list is not the same as sending nothing — it
  /// pins the set to the modes that build knew about — so a full selection is
  /// normalised back to "no restriction".
  static List<TransitMode> _modesFrom(List<String> stored) {
    final modes = [
      for (final name in stored)
        if (TransitMode.fromWire(name) case final mode?) mode,
    ];
    return modes.length >= _legacyModeOptionCount ? const [] : modes;
  }

  /// Size of the mode list the previous Transit options screen offered.
  static const int _legacyModeOptionCount = 28;
}
