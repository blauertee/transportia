import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/constants/prefs_keys.dart';
import 'package:transportia/models/routing_options.dart';
import 'package:transportia/models/transitous/enums.dart';
import 'package:transportia/services/routing_options_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    RoutingOptionsService.invalidate();
  });

  group('round trip', () {
    test('saved options come back unchanged', () async {
      const options = RoutingOptions(
        transitModes: [TransitMode.bus, TransitMode.rail],
        useRoutedTransfers: false,
        wheelchairAccessibleOnly: true,
        bikeCarriageOverride: true,
        noCompulsoryReservation: true,
        via: [
          ViaStopOption(
            stopId: 'de-DELFI_de:11000:900100003',
            name: 'Alexanderplatz',
            minimumStay: Duration(minutes: 10),
          ),
        ],
        maxTransfers: 3,
        additionalTransferTime: Duration(minutes: 6),
        firstMileMode: TransitMode.bike,
        maxFirstMileTime: Duration(minutes: 20),
        directMode: TransitMode.bike,
        maxDirectTime: Duration(minutes: 45),
        walkingSpeedKmh: 5.4,
        cyclingSpeedKmh: 18.0,
        elevationCosts: ElevationCosts.high,
      );

      await RoutingOptionsService.save(options);
      RoutingOptionsService.invalidate();

      expect(await RoutingOptionsService.load(), options);
    });

    test('via stops keep their order, names and stays', () async {
      const options = RoutingOptions(
        via: [
          ViaStopOption(stopId: 'a', name: 'First'),
          ViaStopOption(
            stopId: 'b',
            name: 'Second',
            minimumStay: Duration(minutes: 5),
          ),
        ],
      );
      await RoutingOptionsService.save(options);
      RoutingOptionsService.invalidate();

      final loaded = await RoutingOptionsService.load();
      expect(loaded.via.map((v) => v.stopId), ['a', 'b']);
      expect(loaded.via.last.name, 'Second');
      expect(loaded.via.last.minimumStay, const Duration(minutes: 5));
    });

    test('defaults are used when nothing is stored', () async {
      expect(await RoutingOptionsService.load(), RoutingOptions.defaults);
    });

    test('unreadable storage falls back to defaults', () async {
      final prefs = SharedPreferencesAsync();
      await prefs.setString(PrefsKeys.routingOptions, 'not json');

      expect(await RoutingOptionsService.load(), RoutingOptions.defaults);
    });

    test(
      'an option written by another version does not reset the rest',
      () async {
        final prefs = SharedPreferencesAsync();
        await prefs.setString(
          PrefsKeys.routingOptions,
          '{"maxTransfers":2,"elevationCosts":"EXTREME","firstMileMode":"HOVER"}',
        );

        final loaded = await RoutingOptionsService.load();
        expect(loaded.maxTransfers, 2);
        // Unknown enum values fall back per field rather than failing the read.
        expect(loaded.elevationCosts, ElevationCosts.none);
        expect(loaded.firstMileMode, TransitMode.walk);
      },
    );
  });

  group('migration from the old preference keys', () {
    test('carries the walking speed, transfer buffer and modes', () async {
      final prefs = SharedPreferencesAsync();
      await prefs.setDouble(PrefsKeys.transitWalkingSpeed, 5.2);
      await prefs.setInt(PrefsKeys.transitTransferBuffer, 8);
      await prefs.setStringList(PrefsKeys.transitSelectedModes, const [
        'BUS',
        'RAIL',
      ]);

      final loaded = await RoutingOptionsService.load();
      expect(loaded.walkingSpeedKmh, 5.2);
      expect(loaded.additionalTransferTime, const Duration(minutes: 8));
      expect(loaded.transitModes, [TransitMode.bus, TransitMode.rail]);
    });

    test('a full mode selection becomes no restriction', () async {
      // The old screen wrote out all 28 modes it knew when nothing was
      // deselected. Sending that list would pin the set to those modes.
      final prefs = SharedPreferencesAsync();
      await prefs.setStringList(PrefsKeys.transitSelectedModes, const [
        'WALK',
        'BIKE',
        'RENTAL',
        'CAR',
        'CAR_PARKING',
        'CAR_DROPOFF',
        'ODM',
        'FLEX',
        'TRANSIT',
        'TRAM',
        'SUBWAY',
        'FERRY',
        'AIRPLANE',
        'SUBURBAN',
        'BUS',
        'COACH',
        'RAIL',
        'HIGHSPEED_RAIL',
        'LONG_DISTANCE',
        'NIGHT_RAIL',
        'REGIONAL_FAST_RAIL',
        'REGIONAL_RAIL',
        'CABLE_CAR',
        'FUNICULAR',
        'AERIAL_LIFT',
        'AREAL_LIFT',
        'OTHER',
        'METRO',
      ]);

      expect((await RoutingOptionsService.load()).transitModes, isEmpty);
    });

    test('migrated settings are persisted so it only happens once', () async {
      final prefs = SharedPreferencesAsync();
      await prefs.setInt(PrefsKeys.transitTransferBuffer, 4);

      await RoutingOptionsService.load();
      expect(await prefs.getString(PrefsKeys.routingOptions), isNotNull);
    });

    test('the old keys are left in place for a downgrade', () async {
      final prefs = SharedPreferencesAsync();
      await prefs.setDouble(PrefsKeys.transitWalkingSpeed, 5.2);

      await RoutingOptionsService.load();
      expect(await prefs.getDouble(PrefsKeys.transitWalkingSpeed), 5.2);
    });

    test('stored options win over the old keys', () async {
      final prefs = SharedPreferencesAsync();
      await prefs.setDouble(PrefsKeys.transitWalkingSpeed, 9.9);
      await RoutingOptionsService.save(
        const RoutingOptions(walkingSpeedKmh: 4.0),
      );
      RoutingOptionsService.invalidate();

      expect((await RoutingOptionsService.load()).walkingSpeedKmh, 4.0);
    });
  });

  group('reset', () {
    test('restores the defaults', () async {
      await RoutingOptionsService.save(
        const RoutingOptions(maxTransfers: 1, wheelchairAccessibleOnly: true),
      );
      await RoutingOptionsService.reset();
      RoutingOptionsService.invalidate();

      expect(await RoutingOptionsService.load(), RoutingOptions.defaults);
    });
  });
}
