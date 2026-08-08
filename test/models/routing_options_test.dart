import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/routing_options.dart';
import 'package:transportia/models/transit_mode_group.dart';
import 'package:transportia/models/transitous/enums.dart';

/// Query the options would produce, nulls stripped.
Map<String, String> _query(RoutingOptions options) {
  final params = options.toPlanParams(fromPlace: '0,0', toPlace: '1,1');
  return {
    for (final entry in params.toQuery().entries)
      if (entry.value != null) entry.key: entry.value!,
  };
}

const _bikeBothEnds = RoutingOptions(
  firstMileMode: TransitMode.bike,
  lastMileMode: TransitMode.bike,
);

void main() {
  group('bike carriage follows from having the bike with you', () {
    test('a bike only to the station leaves it there', () {
      const options = RoutingOptions(firstMileMode: TransitMode.bike);
      expect(options.bikeAtBothEnds, isFalse);
      expect(options.requireBikeTransport, isFalse);
      expect(_query(options).containsKey('requireBikeTransport'), isFalse);
    });

    test('a bike at both ends carries it aboard without being asked', () {
      expect(_bikeBothEnds.bikeAtBothEnds, isTrue);
      expect(_bikeBothEnds.requireBikeTransport, isTrue);
      expect(_query(_bikeBothEnds)['requireBikeTransport'], 'true');
    });

    test('walking one end is not enough', () {
      final oneEnd = _bikeBothEnds.copyWith(lastMileMode: TransitMode.walk);
      expect(oneEnd.requireBikeTransport, isFalse);
    });
  });

  group('the rider can still overrule it', () {
    test('turning carriage off with a bike at both ends is honoured', () {
      // The bike is coming, but they would rather walk it onto a service
      // that does not advertise carriage.
      final off = _bikeBothEnds.copyWith(bikeCarriageOverride: false);
      expect(off.requireBikeTransport, isFalse);
      expect(off.bikeCarriageIsManual, isTrue);
      expect(_query(off).containsKey('requireBikeTransport'), isFalse);
    });

    test('a manual choice survives edits elsewhere', () {
      final off = _bikeBothEnds
          .copyWith(bikeCarriageOverride: false)
          .copyWith(maxTransfers: 2)
          .copyWith(noCompulsoryReservation: true);
      expect(off.requireBikeTransport, isFalse);
      expect(off.bikeCarriageIsManual, isTrue);
    });

    test('leaving the bike behind retires the choice', () {
      // Otherwise the value would sit there invisibly: the control only
      // appears with a bike at both ends, so there would be no way to undo it.
      final retired = _bikeBothEnds
          .copyWith(bikeCarriageOverride: false)
          .copyWith(firstMileMode: TransitMode.walk);
      expect(retired.bikeCarriageIsManual, isFalse);

      final backAgain = retired.copyWith(firstMileMode: TransitMode.bike);
      expect(backAgain.requireBikeTransport, isTrue);
    });

    test('a restored override cannot force carriage on its own', () {
      // Storage can hand back an override whose condition no longer holds.
      const orphan = RoutingOptions(bikeCarriageOverride: true);
      expect(orphan.requireBikeTransport, isFalse);
    });
  });

  group('car carriage works the same way', () {
    test('a car at both ends means motorail', () {
      const motorail = RoutingOptions(
        firstMileMode: TransitMode.car,
        lastMileMode: TransitMode.car,
      );
      expect(_query(motorail)['requireCarTransport'], 'true');
    });

    test('park and ride is not motorail', () {
      const parkAndRide = RoutingOptions(
        firstMileMode: TransitMode.carParking,
        lastMileMode: TransitMode.carParking,
      );
      expect(parkAndRide.requireCarTransport, isFalse);
    });
  });

  group('storage', () {
    test('a manual choice round-trips', () {
      final off = _bikeBothEnds.copyWith(bikeCarriageOverride: false);
      final restored = RoutingOptions.fromJson(off.toJson());
      expect(restored.bikeCarriageIsManual, isTrue);
      expect(restored.requireBikeTransport, isFalse);
    });

    test('a flag written by an older build is kept', () {
      final restored = RoutingOptions.fromJson(const {
        'requireBikeTransport': true,
        'firstMileMode': 'BIKE',
        'lastMileMode': 'BIKE',
      });
      expect(restored.requireBikeTransport, isTrue);
    });

    test('an older build with the flag off is left to the derivation', () {
      // False is indistinguishable from the old default, so it is not a
      // decision worth restoring as one.
      final restored = RoutingOptions.fromJson(const {
        'requireBikeTransport': false,
        'firstMileMode': 'BIKE',
        'lastMileMode': 'BIKE',
      });
      expect(restored.bikeCarriageIsManual, isFalse);
      expect(restored.requireBikeTransport, isTrue);
    });
  });

  group('slider ranges', () {
    test('unlimited transfers omits the parameter', () {
      // A large number would still be a limit; the server should keep
      // deciding.
      final unlimited = const RoutingOptions(
        maxTransfers: 2,
      ).withTransfersSliderValue(RoutingOptions.unlimitedTransfersSliderValue);
      expect(unlimited.maxTransfers, isNull);
      expect(_query(unlimited).containsKey('maxTransfers'), isFalse);
    });

    test('the slider round-trips a real limit', () {
      for (var i = 0; i <= RoutingOptions.maxTransferChoice; i++) {
        final withLimit = RoutingOptions.defaults.withTransfersSliderValue(i);
        expect(withLimit.maxTransfers, i);
        expect(withLimit.transfersSliderValue, i);
      }
    });

    test('no limit reads as the top slider position', () {
      expect(
        RoutingOptions.defaults.transfersSliderValue,
        RoutingOptions.unlimitedTransfersSliderValue,
      );
    });

    test('the mile budget tops out at the server ceiling', () {
      expect(RoutingOptions.maxMileBudget, const Duration(hours: 2));
    });
  });

  group('transit selection', () {
    test('untouched options mean every mode', () {
      expect(RoutingOptions.defaults.transitSelection.isEverything, isTrue);
    });

    test('a narrowed selection survives a round trip', () {
      final narrowed = RoutingOptions.defaults.withTransitSelection(
        TransitSelection.everything.toggleGroup(TransitModeGroup.boat),
      );
      expect(narrowed.transitSelection.has(TransitModeGroup.boat), isFalse);
      expect(narrowed.transitSelection.has(TransitModeGroup.rail), isTrue);
    });

    test('an extra reaches the query', () {
      final withFlights = RoutingOptions.defaults.withTransitSelection(
        TransitSelection.everything.toggleExtra(TransitMode.airplane),
      );
      expect(_query(withFlights)['transitModes'], contains('AIRPLANE'));
    });
  });
}
