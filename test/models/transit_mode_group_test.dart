import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/transit_mode_group.dart';
import 'package:transportia/models/transitous/enums.dart';

void main() {
  group('flattening', () {
    test('everything selected sends no restriction at all', () {
      // Sending the full list would pin the set to the modes this build knows
      // about, so a mode added upstream would silently stop being offered.
      expect(TransitSelection.everything.toModes(), isEmpty);
      expect(TransitSelection.everything.isEverything, isTrue);
    });

    test('a narrowed selection expands to its member modes', () {
      const selection = TransitSelection(groups: {TransitModeGroup.bus});
      expect(selection.toModes(), [TransitMode.bus, TransitMode.coach]);
    });

    test('extras are appended to the groups', () {
      const selection = TransitSelection(
        groups: {TransitModeGroup.boat},
        extras: {TransitMode.airplane},
      );
      expect(selection.toModes(), [TransitMode.ferry, TransitMode.airplane]);
    });

    test('nothing selected is distinct from everything selected', () {
      const none = TransitSelection(groups: {});
      expect(none.isEmpty, isTrue);
      expect(none.isEverything, isFalse);
      expect(none.toModes(), isEmpty);
    });
  });

  group('rebuilding from stored modes', () {
    test('round-trips a narrowed selection', () {
      const original = TransitSelection(
        groups: {TransitModeGroup.rail, TransitModeGroup.bus},
        extras: {TransitMode.funicular},
      );
      expect(TransitSelection.fromModes(original.toModes()), original);
    });

    test('an empty list restores everything', () {
      expect(TransitSelection.fromModes(const []), TransitSelection.everything);
    });

    test('a group counts only when all of its modes are present', () {
      // A partial group cannot be represented by the icon, so it does not
      // claim to be on.
      final partial = TransitSelection.fromModes(const [TransitMode.bus]);
      expect(partial.has(TransitModeGroup.bus), isFalse);
    });
  });

  group('grouping choices', () {
    test('tram travels with metro, not with mainline rail', () {
      // Light rail and metro are the same kind of trip for a rider, and it
      // keeps "Rail" meaning mainline.
      expect(TransitModeGroup.metro.modes, contains(TransitMode.tram));
      expect(TransitModeGroup.rail.modes, isNot(contains(TransitMode.tram)));
    });

    test('no mode belongs to two groups', () {
      final seen = <TransitMode>{};
      for (final group in TransitModeGroup.values) {
        for (final mode in group.modes) {
          expect(
            seen.add(mode),
            isTrue,
            reason: '${mode.wireName} is in two groups',
          );
        }
      }
    });

    test('extras do not overlap the groups', () {
      final grouped = {
        for (final group in TransitModeGroup.values) ...group.modes,
      };
      for (final mode in TransitModeGroup.extras) {
        expect(grouped, isNot(contains(mode)), reason: mode.wireName);
      }
    });
  });

  group('summary', () {
    test('says so plainly when nothing is excluded', () {
      expect(TransitSelection.everything.summary(), 'All transport');
    });

    test('enumerates only once something is narrowed', () {
      const selection = TransitSelection(
        groups: {TransitModeGroup.rail, TransitModeGroup.bus},
      );
      expect(selection.summary(), 'Rail, Bus');
    });

    test('names the extras alongside the groups', () {
      const selection = TransitSelection(
        groups: {TransitModeGroup.rail},
        extras: {TransitMode.airplane},
      );
      expect(selection.summary(), 'Rail, Flights');
    });

    test('reports an empty selection rather than pretending', () {
      expect(const TransitSelection(groups: {}).summary(), 'No transport');
    });
  });

  group('toggling', () {
    test('removes and restores a group', () {
      final without = TransitSelection.everything.toggleGroup(
        TransitModeGroup.boat,
      );
      expect(without.has(TransitModeGroup.boat), isFalse);
      expect(without.isEverything, isFalse);
      expect(
        without.toggleGroup(TransitModeGroup.boat),
        TransitSelection.everything,
      );
    });

    test('removes and restores an extra', () {
      final with_ = TransitSelection.everything.toggleExtra(
        TransitMode.airplane,
      );
      expect(with_.extras, {TransitMode.airplane});
      expect(
        with_.toggleExtra(TransitMode.airplane),
        TransitSelection.everything,
      );
    });
  });
}
