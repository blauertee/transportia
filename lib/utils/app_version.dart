import 'package:package_info_plus/package_info_plus.dart';

/// The running app's version, read from the package rather than restated here.
///
/// [load] must run once before [current] is read — `main` does it before
/// anything else. Until then [current] answers [_fallback], so a test that
/// never loads still gets a usable string.
class AppVersion {
  const AppVersion._();

  /// Used only when [load] has not run, as in widget tests.
  static const String _fallback = '0.0.0';

  static String? _current;

  static String get current => _current ?? _fallback;

  static Future<void> load() async {
    final info = await PackageInfo.fromPlatform();
    _current = info.version;
  }

  /// Test seam: sets the version without touching the platform channel.
  static void setForTesting(String? version) => _current = version;
}
