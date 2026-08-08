import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/transitous_endpoint.dart';
import '../constants/prefs_keys.dart';

class BackendProvider extends ChangeNotifier {
  static const String defaultHost = 'api.transitous.org';

  static BackendProvider? _instance;
  static BackendProvider? get instance => _instance;

  String _host = defaultHost;
  String? _apiVersionOverride;
  final Map<String, String> _endpointVersions = {};

  String get host => _host;
  bool get isCustomHost => _host != defaultHost;

  String get apiVersion =>
      _apiVersionOverride ?? _computeDefaultApiVersion(_host);
  bool get isCustomApiVersion => _apiVersionOverride != null;

  /// Version segment to use for [endpoint]: an explicit per-endpoint override
  /// if the user set one, otherwise whatever the endpoint declares as its
  /// default for the current main version.
  String versionFor(TransitousEndpoint endpoint) =>
      _endpointVersions[endpoint.prefKey] ?? defaultVersionFor(endpoint);

  /// Version [endpoint] uses when no override is set.
  String defaultVersionFor(TransitousEndpoint endpoint) =>
      endpoint.defaultVersion(apiVersion);

  bool get hasEndpointOverrides => _endpointVersions.isNotEmpty;
  bool isEndpointOverridden(TransitousEndpoint endpoint) =>
      _endpointVersions.containsKey(endpoint.prefKey);
  String? endpointVersionOverride(TransitousEndpoint endpoint) =>
      _endpointVersions[endpoint.prefKey];

  static String _computeDefaultApiVersion(String host) =>
      host.contains('transitous') ? 'v5' : 'v1';

  static String _endpointPrefKey(String key) =>
      'transitous_api_version_endpoint_$key';

  BackendProvider() {
    _instance = this;
    _load();
  }

  Future<void> _load() async {
    final prefs = SharedPreferencesAsync();
    final savedHost = await prefs.getString(PrefsKeys.transitousHost);
    final savedVersion = await prefs.getString(PrefsKeys.transitousApiVersion);
    if (savedHost != null && savedHost.isNotEmpty) _host = savedHost;
    if (savedVersion != null && savedVersion.isNotEmpty) {
      _apiVersionOverride = savedVersion;
    }
    for (final endpoint in TransitousEndpoint.values) {
      final v = await prefs.getString(_endpointPrefKey(endpoint.prefKey));
      if (v != null && v.isNotEmpty) _endpointVersions[endpoint.prefKey] = v;
    }
    notifyListeners();
  }

  Future<void> setHost(String host) async {
    final trimmed = host.trim();
    final effective = trimmed.isEmpty ? defaultHost : trimmed;
    if (effective == _host) return;
    _host = effective;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    if (_host == defaultHost) {
      await prefs.remove(PrefsKeys.transitousHost);
    } else {
      await prefs.setString(PrefsKeys.transitousHost, _host);
    }
  }

  Future<void> resetHost() => setHost(defaultHost);

  Future<void> setApiVersion(String version) async {
    final trimmed = version.trim();
    final computedDefault = _computeDefaultApiVersion(_host);
    final effective = trimmed.isEmpty || trimmed == computedDefault
        ? null
        : trimmed;
    if (effective == _apiVersionOverride) return;
    _apiVersionOverride = effective;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    if (_apiVersionOverride == null) {
      await prefs.remove(PrefsKeys.transitousApiVersion);
    } else {
      await prefs.setString(
        PrefsKeys.transitousApiVersion,
        _apiVersionOverride!,
      );
    }
  }

  Future<void> resetApiVersion() => setApiVersion('');

  Future<void> setEndpointVersion(
    TransitousEndpoint endpoint,
    String version,
  ) async {
    final trimmed = version.trim();
    if (trimmed.isEmpty) return resetEndpointVersion(endpoint);
    if (_endpointVersions[endpoint.prefKey] == trimmed) return;
    _endpointVersions[endpoint.prefKey] = trimmed;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    await prefs.setString(_endpointPrefKey(endpoint.prefKey), trimmed);
  }

  Future<void> resetEndpointVersion(TransitousEndpoint endpoint) async {
    if (!_endpointVersions.containsKey(endpoint.prefKey)) return;
    _endpointVersions.remove(endpoint.prefKey);
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    await prefs.remove(_endpointPrefKey(endpoint.prefKey));
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }
}
