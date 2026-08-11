import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/utils/changeover.dart';
import 'package:transportia/utils/itinerary_leg_utils.dart';

/// The journey in the report: a long-distance train running late into a
/// two-minute change, and the service it was meant to catch leaving anyway.
final DateTime _t0 = DateTime(2026, 6, 1, 21, 0);

String _at(Duration offset) => _t0.add(offset).toUtc().toIso8601String();

Leg _ride({
  required Duration departs,
  required Duration arrives,
  Duration? scheduledArrival,
  bool realTime = true,
  String from = 'München Hbf',
  String to = 'S Südkreuz',
}) => Leg.fromJson({
  'mode': 'HIGHSPEED_RAIL',
  'startTime': _at(departs),
  'endTime': _at(arrives),
  'scheduledEndTime': _at(scheduledArrival ?? arrives),
  'duration': (arrives - departs).inSeconds,
  'realTime': realTime,
  'from': {
    'name': from,
    'lat': 48.1,
    'lon': 11.5,
    'stopId': 'stop-$from',
    'departure': _at(departs),
  },
  'to': {
    'name': to,
    'lat': 52.4,
    'lon': 13.3,
    'stopId': 'stop-$to',
    'arrival': _at(arrives),
    'scheduledArrival': _at(scheduledArrival ?? arrives),
  },
});

/// The walk across the station, which is what the gap has to cover.
Leg _walk({
  required Duration arrives,
  required Duration departs,
  required Duration takes,
  String at = 'S Südkreuz',
  Duration? startsAt,
}) => Leg.fromJson({
  'mode': 'WALK',
  'startTime': _at(startsAt ?? arrives),
  'endTime': _at(departs),
  'duration': takes.inSeconds,
  'from': {
    'name': at,
    'lat': 52.4,
    'lon': 13.3,
    'stopId': 'stop-$at',
    'arrival': _at(arrives),
    'departure': _at(arrives),
  },
  'to': {'name': at, 'lat': 52.4, 'lon': 13.3, 'stopId': 'stop-$at'},
});

Leg _onward({
  required Duration departs,
  bool realTime = true,
  String from = 'S Südkreuz',
  String to = 'S Westend',
}) => Leg.fromJson({
  'mode': 'SUBURBAN',
  'startTime': _at(departs),
  'endTime': _at(departs + const Duration(minutes: 20)),
  'duration': 1200,
  'realTime': realTime,
  'from': {
    'name': from,
    'lat': 52.4,
    'lon': 13.3,
    'stopId': 'stop-$from',
    'departure': _at(departs),
  },
  'to': {
    'name': to,
    'lat': 52.5,
    'lon': 13.2,
    'stopId': 'stop-$to',
    'arrival': _at(departs + const Duration(minutes: 20)),
  },
});

Changeover _single(List<Leg> legs) =>
    changeoversOf(buildDisplayLegs(legs)).single;

void main() {
  group('whether a change can be made', () {
    test('a service that leaves before you arrive cannot be caught', () {
      // The screenshot exactly: in at :24, the S46 gone at :23.
      final change = _single([
        _ride(
          departs: const Duration(minutes: -300),
          arrives: const Duration(minutes: 24),
          scheduledArrival: const Duration(minutes: 14),
        ),
        _walk(
          arrives: const Duration(minutes: 24),
          departs: const Duration(minutes: 26),
          takes: const Duration(minutes: 2),
        ),
        _onward(departs: const Duration(minutes: 23)),
      ]);

      expect(change.isMissed, isTrue);
      expect(change.gap, const Duration(minutes: -1));
      expect(change.needs, const Duration(minutes: 2));
      expect(change.placeName, 'S Südkreuz');
    });

    test('arriving with less time than the walk takes is still missed', () {
      // Not only a negative gap: one minute to make a two-minute walk is a
      // connection you do not have, and the arithmetic is the same.
      final change = _single([
        _ride(
          departs: const Duration(minutes: -300),
          arrives: const Duration(minutes: 25),
        ),
        _walk(
          arrives: const Duration(minutes: 25),
          departs: const Duration(minutes: 26),
          takes: const Duration(minutes: 2),
        ),
        _onward(departs: const Duration(minutes: 26)),
      ]);

      expect(change.gap, const Duration(minutes: 1));
      expect(change.isMissed, isTrue);
    });

    test('time enough for the walk is not flagged', () {
      final change = _single([
        _ride(
          departs: const Duration(minutes: -300),
          arrives: const Duration(minutes: 20),
        ),
        _walk(
          arrives: const Duration(minutes: 20),
          departs: const Duration(minutes: 26),
          takes: const Duration(minutes: 2),
        ),
        _onward(departs: const Duration(minutes: 26)),
      ]);

      expect(change.isMissed, isFalse);
    });

    test('the same numbers with nobody reporting are not flagged', () {
      // A planner never builds a change it cannot make, so an impossible gap
      // with no real-time behind it is bad data, not a broken journey — and
      // every saved trip opened offline would otherwise shout.
      final change = _single([
        _ride(
          departs: const Duration(minutes: -300),
          arrives: const Duration(minutes: 24),
          realTime: false,
        ),
        _walk(
          arrives: const Duration(minutes: 24),
          departs: const Duration(minutes: 26),
          takes: const Duration(minutes: 2),
        ),
        _onward(departs: const Duration(minutes: 23), realTime: false),
      ]);

      expect(change.gap, const Duration(minutes: -1));
      expect(change.isLive, isFalse);
      expect(change.isMissed, isFalse);
    });

    test('one side reporting is enough to judge it', () {
      final change = _single([
        _ride(
          departs: const Duration(minutes: -300),
          arrives: const Duration(minutes: 24),
          realTime: true,
        ),
        _walk(
          arrives: const Duration(minutes: 24),
          departs: const Duration(minutes: 26),
          takes: const Duration(minutes: 2),
        ),
        _onward(departs: const Duration(minutes: 23), realTime: false),
      ]);

      expect(change.isMissed, isTrue);
    });

    test('the gap is measured from the arrival, not the walk', () {
      // MOTIS pads a transfer walk forward: the train is in at :13 and the
      // walk is timed from :16. Measuring from the walk would throw away
      // three minutes the rider actually has and call a fine change broken.
      final change = _single([
        _ride(
          departs: const Duration(minutes: -300),
          arrives: const Duration(minutes: 13),
        ),
        _walk(
          arrives: const Duration(minutes: 13),
          startsAt: const Duration(minutes: 16),
          departs: const Duration(minutes: 18),
          takes: const Duration(minutes: 4),
        ),
        _onward(departs: const Duration(minutes: 18)),
      ]);

      expect(change.gap, const Duration(minutes: 5));
      expect(change.isMissed, isFalse);
    });

    test('a walk off the end of the journey is not a change', () {
      // Nothing to catch, so nothing to miss. The last walk is the way home.
      final legs = [
        _ride(
          departs: const Duration(minutes: -300),
          arrives: const Duration(minutes: 24),
        ),
        _walk(
          arrives: const Duration(minutes: 24),
          departs: const Duration(minutes: 26),
          takes: const Duration(minutes: 30),
        ),
      ];

      expect(changeoversOf(buildDisplayLegs(legs)), isEmpty);
    });

    test('every change in a journey is found, in order', () {
      final changes = changeoversOf(
        buildDisplayLegs([
          _ride(
            departs: const Duration(minutes: -300),
            arrives: const Duration(minutes: 24),
            to: 'S Südkreuz',
          ),
          _walk(
            arrives: const Duration(minutes: 24),
            departs: const Duration(minutes: 26),
            takes: const Duration(minutes: 2),
            at: 'S Südkreuz',
          ),
          _onward(
            departs: const Duration(minutes: 23),
            from: 'S Südkreuz',
            to: 'S Westend',
          ),
          _walk(
            arrives: const Duration(minutes: 43),
            departs: const Duration(minutes: 45),
            takes: const Duration(minutes: 2),
            at: 'S Westend',
          ),
          _onward(
            departs: const Duration(minutes: 50),
            from: 'S Westend',
            to: 'Home',
          ),
        ]),
      );

      expect(changes.map((c) => c.placeName), ['S Südkreuz', 'S Westend']);
      expect(changes.first.isMissed, isTrue);
      expect(changes.last.isMissed, isFalse);
    });
  });

  group('the journey to offer instead', () {
    List<Leg> journey() => [
      _ride(
        departs: const Duration(minutes: 0),
        arrives: const Duration(minutes: 24),
        from: 'München Hbf',
        to: 'S Südkreuz',
      ),
      _walk(
        arrives: const Duration(minutes: 24),
        departs: const Duration(minutes: 26),
        takes: const Duration(minutes: 2),
      ),
      _onward(
        departs: const Duration(minutes: 23),
        from: 'S Südkreuz',
        to: 'S Westend',
      ),
    ];

    test('before it starts, the whole journey again', () {
      // A different first train is still open to you.
      final replan = replanFor(
        journey(),
        _t0.subtract(const Duration(hours: 1)),
      )!;

      expect(replan.from.name, 'München Hbf');
      expect(replan.to.name, 'S Westend');
    });

    test('the head start keeps the search off this very minute', () {
      final now = _t0.subtract(const Duration(hours: 1));
      final replan = replanFor(journey(), now)!;

      expect(replan.departAt, now.add(kReplanHeadStart));
    });

    test('under way, it leaves from the station ahead', () {
      // Mid-ride there is nowhere else to get off, so the search starts where
      // the train is actually going.
      final replan = replanFor(
        journey(),
        _t0.add(const Duration(minutes: 10)),
      )!;

      expect(replan.from.name, 'S Südkreuz');
      expect(replan.to.name, 'S Westend');
    });

    test('and never before you get there', () {
      // Ten minutes from now is forty minutes before the train pulls in;
      // searching then answers with services you cannot board.
      final now = _t0.add(const Duration(minutes: 10));
      final replan = replanFor(journey(), now)!;

      expect(replan.departAt.isAfter(now.add(kReplanHeadStart)), isTrue);
      expect(
        replan.departAt.toUtc(),
        _t0.add(const Duration(minutes: 24)).toUtc(),
      );
    });

    test('the head start wins once you are standing there', () {
      // Arrived, so the constraint is you rather than the train.
      final now = _t0.add(const Duration(minutes: 24));
      final replan = replanFor(journey(), now)!;

      expect(replan.departAt, now.add(kReplanHeadStart));
    });

    test('it never offers to travel from the destination to itself', () {
      // The last leg is the walk home, and its end is a doorstep rather than
      // somewhere a search can leave from.
      final legs = [
        _ride(
          departs: const Duration(minutes: 0),
          arrives: const Duration(minutes: 24),
          from: 'München Hbf',
          to: 'S Südkreuz',
        ),
        _walk(
          arrives: const Duration(minutes: 24),
          departs: const Duration(minutes: 40),
          takes: const Duration(minutes: 16),
          at: 'Home',
        ),
      ];
      final replan = replanFor(legs, _t0.add(const Duration(minutes: 30)))!;

      expect(replan.from.name, isNot(replan.to.name));
    });

    test('a journey with no legs has nothing to offer', () {
      expect(replanFor(const [], _t0), isNull);
    });
  });
}
