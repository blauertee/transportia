import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/transitous/enums.dart';

void main() {
  group('lenient parsing', () {
    // MOTIS documents that experimental fields change without version bumps,
    // so an unknown value has to be survivable rather than fatal.
    test('unknown values parse to null instead of throwing', () {
      expect(TransitMode.fromWire('QUANTUM_TELEPORT'), isNull);
      expect(AlertEffect.fromWire('BRAND_NEW_EFFECT'), isNull);
      expect(RealtimeMode.fromWire('FULL'), isNull);
    });

    test('absent and wrongly typed values parse to null', () {
      expect(TransitMode.fromWire(null), isNull);
      expect(TransitMode.fromWire(42), isNull);
      expect(TransitMode.fromWire(const {'mode': 'BUS'}), isNull);
    });

    test('matching is exact, not case insensitive', () {
      expect(TransitMode.fromWire('bus'), isNull);
      expect(TransitMode.fromWire('BUS'), TransitMode.bus);
    });
  });

  group('wire names', () {
    test('round-trip through fromWire', () {
      for (final mode in TransitMode.values) {
        expect(TransitMode.fromWire(mode.wireName), mode);
      }
      for (final cause in AlertCause.values) {
        expect(AlertCause.fromWire(cause.wireName), cause);
      }
      for (final factor in RentalFormFactor.values) {
        expect(RentalFormFactor.fromWire(factor.wireName), factor);
      }
    });

    test('are unique within an enum', () {
      final names = TransitMode.values.map((m) => m.wireName).toSet();
      expect(names, hasLength(TransitMode.values.length));
    });

    test('deprecated mode aliases are still accepted', () {
      // The server still emits these; dropping them would silently reclassify
      // legs as unknown.
      expect(TransitMode.fromWire('METRO'), TransitMode.metro);
      expect(TransitMode.fromWire('AREAL_LIFT'), TransitMode.arealLift);
      expect(TransitMode.fromWire('CABLE_CAR'), TransitMode.cableCar);
      expect(
        TransitMode.fromWire('REGIONAL_FAST_RAIL'),
        TransitMode.regionalFastRail,
      );
    });
  });

  group('street modes', () {
    test('street modes are separated from timetabled ones', () {
      expect(TransitMode.walk.isStreetMode, isTrue);
      expect(TransitMode.rental.isStreetMode, isTrue);
      expect(TransitMode.bus.isStreetMode, isFalse);
      expect(TransitMode.transit.isStreetMode, isFalse);
    });
  });
}
