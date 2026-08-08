import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/stop_time.dart';

/// Parses the real captures in `test/fixtures/transitous/`.
///
/// Hand-written JSON tends to agree with whatever the parser already assumes;
/// these are what the server actually sends, exponential numbers and absent
/// optional fields included.
dynamic _fixture(String name) =>
    json.decode(File('test/fixtures/transitous/$name').readAsStringSync());

void main() {
  group('plan.json', () {
    late Map<String, dynamic> plan;

    setUpAll(() => plan = _fixture('plan.json') as Map<String, dynamic>);

    test('parses every itinerary', () {
      final itineraries = (plan['itineraries'] as List)
          .map((i) => Itinerary.fromJson(i as Map<String, dynamic>))
          .toList();

      expect(itineraries, isNotEmpty);
      for (final itinerary in itineraries) {
        expect(itinerary.legs, isNotEmpty);
        expect(itinerary.endTime.isAfter(itinerary.startTime), isTrue);
      }
    });

    test('carries the itinerary id needed to refresh it', () {
      final itinerary = Itinerary.fromJson(
        (plan['itineraries'] as List).first as Map<String, dynamic>,
      );
      // This is the handle /refresh-itinerary takes, and the reason that call
      // has to be a POST.
      expect(itinerary.id, isNotNull);
      expect(itinerary.id!.length, greaterThan(100));
    });

    test('reads leg endpoints as full places', () {
      final itinerary = Itinerary.fromJson(
        (plan['itineraries'] as List).first as Map<String, dynamic>,
      );
      final leg = itinerary.legs.first;

      expect(leg.from.name, isNotEmpty);
      expect(leg.from.lat, isNot(0.0));
      expect(leg.fromName, leg.from.name);
      expect(leg.fromLat, leg.from.lat);
    });

    test('reads the transit leg details the app previously dropped', () {
      final itinerary = (plan['itineraries'] as List)
          .map((i) => Itinerary.fromJson(i as Map<String, dynamic>))
          .firstWhere((i) => i.legs.any((l) => l.tripId != null));
      final transit = itinerary.legs.firstWhere((l) => l.tripId != null);

      expect(transit.routeId, isNotNull);
      expect(transit.source, isNotNull);
      expect(transit.tripFrom, isNotNull);
      expect(transit.tripTo, isNotNull);
      expect(transit.transitMode, isNotNull);
    });

    test('reads walking steps when detailed legs are requested', () {
      final legs = (plan['itineraries'] as List)
          .expand((i) => Itinerary.fromJson(i as Map<String, dynamic>).legs)
          .toList();
      final withSteps = legs.where((l) => l.steps.isNotEmpty);

      expect(withSteps, isNotEmpty, reason: 'detailedLegs=true was requested');
      final step = withSteps.first.steps.first;
      expect(step.distance, greaterThanOrEqualTo(0));
      expect(step.polyline, isNotNull);
    });

    test('keeps the raw payload so an itinerary stays saveable', () {
      final itinerary = Itinerary.fromJson(
        (plan['itineraries'] as List).first as Map<String, dynamic>,
      );
      expect(itinerary.sourceJson, isNotNull);
      expect(
        Itinerary.fromJson(itinerary.sourceJson!).startTime,
        itinerary.startTime,
      );
    });
  });

  group('trip.json', () {
    test('parses as an itinerary', () {
      final trip = Itinerary.fromJson(_fixture('trip.json'));
      expect(trip.legs, isNotEmpty);
      expect(trip.legs.first.intermediateStops, isNotEmpty);
    });
  });

  group('stoptimes.json', () {
    test('parses the response and its places', () {
      final response = StopTimesResponse.fromJson(
        _fixture('stoptimes.json') as Map<String, dynamic>,
      );

      expect(response.stopTimes, isNotEmpty);
      final stopTime = response.stopTimes.first;
      expect(stopTime.place.name, isNotEmpty);
      expect(stopTime.tripId, isNotEmpty);
      expect(response.nextPageCursor, isNotNull);
    });
  });

  group('stop.json', () {
    test('parses as a place', () {
      final json = _fixture('stop.json') as Map<String, dynamic>;
      final place = TransitPlace.fromJson(
        json['place'] as Map<String, dynamic>,
      );

      expect(place.name, isNotEmpty);
      expect(place.isStop, isTrue);
      // /stop is the endpoint that reports which modes serve a stop.
      expect(place.modes, isNotEmpty);
      expect(place.modes, everyElement(isA<TransitMode>()));
    });
  });

  group('numbers', () {
    test('exponential integers survive parsing', () {
      // MOTIS writes every number in exponential form, so `duration` arrives
      // as 8.46E3 rather than 8460 and a plain `as int` cast would throw.
      final raw = json.encode({
        'duration': 8.46e3,
        'startTime': '2026-08-08T09:20:00Z',
        'endTime': '2026-08-08T11:41:00Z',
        'transfers': 2.0,
        'id': 'abc',
        'legs': <Object>[],
      });
      final itinerary = Itinerary.fromJson(
        json.decode(raw) as Map<String, dynamic>,
      );

      expect(itinerary.duration, 8460);
      expect(itinerary.transfers, 2);
    });
  });
}
