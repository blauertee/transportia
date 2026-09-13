import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/prefs_keys.dart';
import '../utils/app_version.dart';
import 'migrate_1_0_3_to_1_0_4.dart';

/// Brings stored preferences up to what the running build expects.
///
/// Exactly one migration exists at a time, spanning the last released version
/// and the one in development. Run once from `main` before `runApp`: every
/// service reads storage lazily on first use, so anything later is a race.
class StorageMigrations {
  const StorageMigrations._();

  static Future<void> run() async {
    try {
      await _migrate(SharedPreferencesAsync());
    } catch (error, stackTrace) {
      // Stale settings beat a launch that never finishes.
      developer.log(
        'Storage migration failed; continuing with storage as found',
        name: 'StorageMigrations',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _migrate(SharedPreferencesAsync prefs) async {
    final stored = await prefs.getString(PrefsKeys.storageVersion);
    final current = AppVersion.current;

    if (stored == current) return;

    if (stored == null) {
      await _migrateUnstamped(prefs, current);
      return;
    }

    if (_isNewerThanCurrent(stored, current)) {
      // A downgraded install. Downgrades are not supported, so leave the data
      // as it is and leave the stamp saying which build really wrote it.
      developer.log(
        'Storage was written by $stored, newer than $current; leaving it alone',
        name: 'StorageMigrations',
      );
      return;
    }

    if (stored == MigrateV103ToV104.from) {
      await MigrateV103ToV104.run(prefs);
    }
    await prefs.setString(PrefsKeys.storageVersion, current);
  }

  /// No stamp means either 1.0.3, which never wrote one, or a fresh install.
  /// What 1.0.3 left behind tells them apart.
  static Future<void> _migrateUnstamped(
    SharedPreferencesAsync prefs,
    String current,
  ) async {
    if (await MigrateV103ToV104.hasTraces(prefs)) {
      await MigrateV103ToV104.run(prefs);
    }
    await prefs.setString(PrefsKeys.storageVersion, current);
  }

  /// Compares dotted versions numerically, so 1.0.10 sorts above 1.0.9.
  /// Anything unparseable counts as not newer, which keeps migration running
  /// rather than silently skipping it.
  static bool _isNewerThanCurrent(String stored, String current) {
    final a = _parts(stored);
    final b = _parts(current);
    if (a == null || b == null) return false;

    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return a.length > b.length;
  }

  static List<int>? _parts(String version) {
    final parts = <int>[];
    for (final segment in version.split('.')) {
      final value = int.tryParse(segment);
      if (value == null) return null;
      parts.add(value);
    }
    return parts.isEmpty ? null : parts;
  }
}
