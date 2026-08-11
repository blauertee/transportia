import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/journey_progress.dart';

final DateTime _leaves = DateTime.utc(2026, 6, 1, 10);
final DateTime _arrives = DateTime.utc(2026, 6, 1, 11);

JourneyProgress _at(Duration offset) => JourneyProgress(_leaves.add(offset));

void main() {
  group('how far along a stretch the traveller is', () {
    test('nothing is behind you before it starts', () {
      expect(
        _at(const Duration(minutes: -30)).fractionBetween(_leaves, _arrives),
        0,
      );
      // Standing at the departure counts as not yet gone.
      expect(_at(Duration.zero).fractionBetween(_leaves, _arrives), 0);
    });

    test('all of it is behind you once it is over', () {
      expect(
        _at(const Duration(hours: 2)).fractionBetween(_leaves, _arrives),
        1,
      );
      expect(
        _at(const Duration(hours: 1)).fractionBetween(_leaves, _arrives),
        1,
      );
    });

    test('part-way through, it is the part done', () {
      expect(
        _at(const Duration(minutes: 15)).fractionBetween(_leaves, _arrives),
        0.25,
      );
      expect(
        _at(const Duration(minutes: 45)).fractionBetween(_leaves, _arrives),
        0.75,
      );
    });

    test('a stretch nobody timed is drawn whole', () {
      // Guessing here would claim the traveller had got further than anyone
      // knows, which is the one thing an indicator must not do.
      final now = _at(const Duration(minutes: 30));
      expect(now.fractionBetween(null, _arrives), 0);
      expect(now.fractionBetween(_leaves, null), 0);
      expect(now.fractionBetween(null, null), 0);
    });

    test('a stretch that takes no time is one side or the other', () {
      expect(
        _at(const Duration(minutes: -1)).fractionBetween(_leaves, _leaves),
        0,
      );
      expect(
        _at(const Duration(minutes: 1)).fractionBetween(_leaves, _leaves),
        1,
      );
    });

    test('with no clock, nothing has been travelled', () {
      // The default everywhere a caller has no clock to offer.
      expect(JourneyProgress.never.fractionBetween(_leaves, _arrives), 0);
      expect(JourneyProgress.never.hasPassed(_leaves), isFalse);
    });
  });

  group('whether a moment is behind you', () {
    test('the moment itself counts as reached', () {
      expect(_at(Duration.zero).hasPassed(_leaves), isTrue);
    });

    test('a moment still to come has not', () {
      expect(_at(const Duration(minutes: -1)).hasPassed(_leaves), isFalse);
    });

    test('a moment nobody knows has not', () {
      expect(_at(const Duration(hours: 5)).hasPassed(null), isFalse);
    });
  });
}
