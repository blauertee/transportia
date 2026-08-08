import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../api/endpoints/map_endpoint.dart';
import '../models/transitous/server_config.dart';

/// What the connected server supports, fetched once and cached.
///
/// The routing options need this: a server without elevation data or street
/// routing cannot honour those options, and the budget controls should not
/// offer values the server will silently clamp. Until the fetch lands, and if
/// it fails, [ServerConfig.fallback] keeps the UI usable with Transitous's
/// published limits.
class ServerCapabilitiesService {
  const ServerCapabilitiesService._();

  /// Current capabilities. Rebuild anything that reads limits when this
  /// changes.
  static final ValueNotifier<ServerConfig> capabilities =
      ValueNotifier<ServerConfig>(ServerConfig.fallback);

  static Future<void>? _inFlight;
  static bool _loaded = false;

  /// True once a real answer has replaced the fallback.
  static bool get isLoaded => _loaded;

  /// Fetches the capabilities unless they are already loaded.
  ///
  /// Concurrent callers share one request.
  static Future<ServerConfig> ensureLoaded() async {
    if (_loaded) return capabilities.value;
    await (_inFlight ??= _load());
    return capabilities.value;
  }

  /// Fetches again even if already loaded, e.g. after the user points the app
  /// at a different backend.
  static Future<ServerConfig> refresh() async {
    _loaded = false;
    _inFlight = null;
    return ensureLoaded();
  }

  /// Drops the cache without fetching. Used when the host changes, so the
  /// next read reflects the new server rather than the old one.
  static void invalidate() {
    _loaded = false;
    _inFlight = null;
    capabilities.value = ServerConfig.fallback;
  }

  static Future<void> _load() async {
    try {
      final initial = await MapEndpoint.initial();
      capabilities.value = initial.serverConfig;
      _loaded = true;
    } catch (e) {
      // Keeping the fallback is better than blocking the settings screen; the
      // server enforces its own limits regardless of what we offer.
      developer.log(
        'Could not read server capabilities, using defaults',
        name: 'ServerCapabilitiesService',
        error: e,
      );
    } finally {
      _inFlight = null;
    }
  }
}
