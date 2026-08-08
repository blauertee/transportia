import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/api/transitous_client.dart';
import 'package:transportia/constants/prefs_keys.dart';
import 'package:transportia/models/time_selection.dart';
import 'package:transportia/services/routing_service.dart';

/// Captures the request RoutingService makes, without a network.
late Uri lastRequest;

TransitousClient _capturingClient() => TransitousClient(
  httpClient: MockClient((request) async {
    lastRequest = request.url;
    return http.Response(
      json.encode(const {'itineraries': <Object>[]}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TransitousClient original;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    original = TransitousClient.instance;
    TransitousClient.instance = _capturingClient();
  });

  tearDown(() => TransitousClient.instance = original);

  Future<Map<String, String>> plan({TimeSelection? timeSelection}) async {
    await RoutingService.findRoutesPaginated(
      fromLat: 52.52,
      fromLon: 13.405,
      toLat: 53.5511,
      toLon: 9.9937,
      timeSelection: timeSelection,
    );
    return lastRequest.queryParameters;
  }

  test('targets the plan endpoint on the configured API version', () async {
    await plan();
    expect(lastRequest.host, 'api.transitous.org');
    expect(lastRequest.path, '/api/v6/plan');
  });

  test('sends endpoints as comma-separated coordinates', () async {
    final query = await plan();
    expect(query['fromPlace'], '52.520000,13.405000');
    expect(query['toPlace'], '53.551100,9.993700');
  });

  test('asks for fares and routed transfers', () async {
    final query = await plan();
    expect(query['withFares'], 'true');
    expect(query['useRoutedTransfers'], 'true');
  });

  test('omits the stored options that are unset', () async {
    final query = await plan();
    expect(query.containsKey('pedestrianSpeed'), isFalse);
    expect(query.containsKey('additionalTransferTime'), isFalse);
    expect(query.containsKey('transitModes'), isFalse);
    expect(query.containsKey('time'), isFalse);
  });

  test('converts the stored walking speed from km/h to m/s', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setDouble(PrefsKeys.transitWalkingSpeed, 5.4);

    final query = await plan();
    expect(double.parse(query['pedestrianSpeed']!), closeTo(1.5, 0.0001));
  });

  test('sends the transfer buffer in minutes', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setInt(PrefsKeys.transitTransferBuffer, 7);

    expect((await plan())['additionalTransferTime'], '7');
  });

  test('drops a zero transfer buffer rather than sending it', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setInt(PrefsKeys.transitTransferBuffer, 0);

    expect((await plan()).containsKey('additionalTransferTime'), isFalse);
  });

  test(
    'sends the selected modes, skipping ones this build cannot map',
    () async {
      final prefs = SharedPreferencesAsync();
      await prefs.setStringList(PrefsKeys.transitSelectedModes, const [
        'BUS',
        'RAIL',
        // A mode saved by a future build, or removed upstream.
        'TELEPORT',
      ]);

      expect((await plan())['transitModes'], 'BUS,RAIL');
    },
  );

  test('sends the chosen departure time', () async {
    final query = await plan(
      timeSelection: TimeSelection(
        dateTime: DateTime.utc(2026, 8, 10, 8),
        isArriveBy: false,
      ),
    );

    expect(query['time'], '2026-08-10T08:00:00.000Z');
    expect(query['arriveBy'], 'false');
  });

  test('sends arriveBy for an arrival time', () async {
    final query = await plan(
      timeSelection: TimeSelection(
        dateTime: DateTime.utc(2026, 8, 10, 8),
        isArriveBy: true,
      ),
    );

    expect(query['arriveBy'], 'true');
  });

  test('leaves the time out when departing now', () async {
    final query = await plan(timeSelection: TimeSelection.now());

    expect(query.containsKey('time'), isFalse);
    expect(query.containsKey('arriveBy'), isFalse);
  });
}
