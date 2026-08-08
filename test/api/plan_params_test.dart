import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/api/params/plan_params.dart';
import 'package:transportia/models/transitous/enums.dart';

const _from = '52.520000,13.405000';
const _to = '53.551100,9.993700';

PlanParams _minimal() => const PlanParams(fromPlace: _from, toPlace: _to);

/// Query with nulls stripped, i.e. what actually reaches the wire.
Map<String, String> _sent(PlanParams params) => {
  for (final entry in params.toQuery().entries)
    if (entry.value != null) entry.key: entry.value!,
};

void main() {
  group('minimal request', () {
    test('sends only the two required parameters', () {
      // MOTIS ignores unknown parameters silently, so anything we send that
      // we did not mean to send would never surface as an error. Keeping the
      // minimal query minimal is the only way that stays visible.
      expect(_sent(_minimal()), {'fromPlace': _from, 'toPlace': _to});
    });

    test('leaves server defaults alone rather than restating them', () {
      // Restating a default pins it: when the server changes its default, a
      // hardcoded copy silently keeps the old behaviour.
      final sent = _sent(_minimal());
      expect(sent.containsKey('numItineraries'), isFalse);
      expect(sent.containsKey('detailedLegs'), isFalse);
      expect(sent.containsKey('realtimeMode'), isFalse);
      expect(sent.containsKey('timetableView'), isFalse);
    });
  });

  group('durations use the unit each parameter expects', () {
    test('minutes for travel and transfer times', () {
      final sent = _sent(
        const PlanParams(
          fromPlace: _from,
          toPlace: _to,
          maxTravelTime: Duration(hours: 2),
          minTransferTime: Duration(minutes: 3),
          additionalTransferTime: Duration(minutes: 5),
        ),
      );

      expect(sent['maxTravelTime'], '120');
      expect(sent['minTransferTime'], '3');
      expect(sent['additionalTransferTime'], '5');
    });

    test('seconds for the street and search budgets', () {
      final sent = _sent(
        const PlanParams(
          fromPlace: _from,
          toPlace: _to,
          searchWindow: Duration(minutes: 30),
          maxPreTransitTime: Duration(minutes: 20),
          maxPostTransitTime: Duration(minutes: 20),
          maxDirectTime: Duration(minutes: 45),
          timeout: Duration(seconds: 90),
        ),
      );

      expect(sent['searchWindow'], '1800');
      expect(sent['maxPreTransitTime'], '1200');
      expect(sent['maxPostTransitTime'], '1200');
      expect(sent['maxDirectTime'], '2700');
      expect(sent['timeout'], '90');
    });
  });

  group('via stops', () {
    test('stop ids and stays stay positionally aligned', () {
      final sent = _sent(
        const PlanParams(
          fromPlace: _from,
          toPlace: _to,
          via: [
            ViaStop(stopId: 'de-DELFI_de:11000:900100003'),
            ViaStop(
              stopId: 'de-DELFI_de:11000:900003201',
              minimumStay: Duration(minutes: 10),
            ),
          ],
        ),
      );

      expect(
        sent['via'],
        'de-DELFI_de:11000:900100003,de-DELFI_de:11000:900003201',
      );
      // Minutes, and one entry per via stop.
      expect(sent['viaMinimumStay'], '0,10');
    });

    test('no stay list is sent when there are no via stops', () {
      final sent = _sent(_minimal());
      expect(sent.containsKey('via'), isFalse);
      expect(sent.containsKey('viaMinimumStay'), isFalse);
    });
  });

  group('enums and lists', () {
    test('modes are sent as comma-joined wire names', () {
      final sent = _sent(
        const PlanParams(
          fromPlace: _from,
          toPlace: _to,
          transitModes: [TransitMode.bus, TransitMode.rail],
          preTransitModes: [TransitMode.bike],
          postTransitModes: [TransitMode.walk],
          directModes: [TransitMode.walk, TransitMode.bike],
        ),
      );

      expect(sent['transitModes'], 'BUS,RAIL');
      expect(sent['preTransitModes'], 'BIKE');
      expect(sent['postTransitModes'], 'WALK');
      expect(sent['directModes'], 'WALK,BIKE');
    });

    test('empty mode lists are omitted, not sent as an empty string', () {
      // An empty transitModes would mean "no transit at all" to the server.
      final sent = _sent(_minimal());
      expect(sent.containsKey('transitModes'), isFalse);
    });

    test('enum-valued options use their wire names', () {
      final sent = _sent(
        const PlanParams(
          fromPlace: _from,
          toPlace: _to,
          pedestrianProfile: PedestrianProfile.wheelchair,
          elevationCosts: ElevationCosts.high,
          realtimeMode: RealtimeMode.annotationOnly,
        ),
      );

      expect(sent['pedestrianProfile'], 'WHEELCHAIR');
      expect(sent['elevationCosts'], 'HIGH');
      expect(sent['realtimeMode'], 'REALTIME_ANNOTATION_ONLY');
    });
  });

  group('the options behind the Transitous options panel', () {
    test('all of them reach the query', () {
      final sent = _sent(
        const PlanParams(
          fromPlace: _from,
          toPlace: _to,
          useRoutedTransfers: true,
          pedestrianProfile: PedestrianProfile.wheelchair,
          requireBikeTransport: true,
          requireCarTransport: true,
          noCompulsoryReservation: true,
          maxTransfers: 4,
          additionalTransferTime: Duration(minutes: 5),
          preTransitModes: [TransitMode.walk],
          maxPreTransitTime: Duration(minutes: 15),
          postTransitModes: [TransitMode.walk],
          maxPostTransitTime: Duration(minutes: 15),
          directModes: [TransitMode.walk],
          maxDirectTime: Duration(minutes: 30),
          pedestrianSpeed: 1.2,
          cyclingSpeed: 4.2,
          elevationCosts: ElevationCosts.low,
        ),
      );

      expect(sent, containsPair('useRoutedTransfers', 'true'));
      expect(sent, containsPair('pedestrianProfile', 'WHEELCHAIR'));
      expect(sent, containsPair('requireBikeTransport', 'true'));
      expect(sent, containsPair('requireCarTransport', 'true'));
      expect(sent, containsPair('noCompulsoryReservation', 'true'));
      expect(sent, containsPair('maxTransfers', '4'));
      expect(sent, containsPair('additionalTransferTime', '5'));
      expect(sent, containsPair('maxPreTransitTime', '900'));
      expect(sent, containsPair('maxPostTransitTime', '900'));
      expect(sent, containsPair('maxDirectTime', '1800'));
      expect(sent, containsPair('pedestrianSpeed', '1.2'));
      expect(sent, containsPair('cyclingSpeed', '4.2'));
      expect(sent, containsPair('elevationCosts', 'LOW'));
    });
  });

  group('rental filters', () {
    test('each portion emits its own prefixed parameters', () {
      final sent = _sent(
        const PlanParams(
          fromPlace: _from,
          toPlace: _to,
          preTransitRentals: RentalFilters(
            formFactors: [RentalFormFactor.bicycle],
            providers: ['de-NextbikeBerlin'],
            ignoreReturnConstraints: true,
          ),
          directRentals: RentalFilters(
            propulsionTypes: [RentalPropulsionType.electric],
            providerGroups: ['nextbike Berlin'],
          ),
        ),
      );

      expect(sent['preTransitRentalFormFactors'], 'BICYCLE');
      expect(sent['preTransitRentalProviders'], 'de-NextbikeBerlin');
      expect(sent['ignorePreTransitRentalReturnConstraints'], 'true');
      expect(sent['directRentalPropulsionTypes'], 'ELECTRIC');
      expect(sent['directRentalProviderGroups'], 'nextbike Berlin');
      // The untouched portion contributes nothing.
      expect(
        sent.keys.where((k) => k.startsWith('postTransitRental')),
        isEmpty,
      );
    });
  });

  group('lorry profile', () {
    test('is only sent when set', () {
      expect(
        _sent(_minimal()).keys.where((k) => k.startsWith('vehicle')),
        isEmpty,
      );

      final sent = _sent(
        const PlanParams(
          fromPlace: _from,
          toPlace: _to,
          vehicle: VehicleProfile(
            height: 4.0,
            weight: 40.0,
            axleCount: 5,
            hazmat: true,
            lezAccess: false,
          ),
        ),
      );
      expect(sent['vehicleHeight'], '4');
      expect(sent['vehicleWeight'], '40');
      expect(sent['vehicleAxleCount'], '5');
      expect(sent['vehicleHazmat'], 'true');
      expect(sent['vehicleLezAccess'], 'false');
    });
  });

  group('time', () {
    test('is sent as UTC with millisecond precision', () {
      final sent = _sent(
        PlanParams(
          fromPlace: _from,
          toPlace: _to,
          time: DateTime.utc(2026, 8, 10, 8),
          arriveBy: true,
        ),
      );

      expect(sent['time'], '2026-08-10T08:00:00.000Z');
      expect(sent['arriveBy'], 'true');
    });
  });

  group('copyWith', () {
    test('carries paging without disturbing the rest of the query', () {
      const original = PlanParams(
        fromPlace: _from,
        toPlace: _to,
        transitModes: [TransitMode.bus],
        maxTransfers: 2,
        withFares: true,
      );
      final paged = original.copyWith(pageCursor: 'CURSOR');

      expect(_sent(paged)['pageCursor'], 'CURSOR');
      expect(
        _sent(paged)..remove('pageCursor'),
        _sent(original)..remove('pageCursor'),
      );
    });
  });
}
