import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/utils/journey_utils.dart';

final DateTime _departure = DateTime.utc(2026, 6, 1, 10);

TransitPlace _place(
  String name, {
  DateTime? arrival,
  DateTime? departure,
  List<Alert> alerts = const [],
}) => TransitPlace(
  name: name,
  lat: 0,
  lon: 0,
  stopId: name,
  arrival: arrival,
  departure: departure,
  alerts: alerts,
);

Leg _leg({
  List<Alert> legAlerts = const [],
  List<TransitPlace> intermediateStops = const [],
}) => Leg(
  mode: 'BUS',
  from: _place('Origin', departure: _departure),
  to: _place('Terminus', arrival: _departure.add(const Duration(minutes: 20))),
  startTime: _departure,
  endTime: _departure.add(const Duration(minutes: 20)),
  duration: 1200,
  alerts: legAlerts,
  intermediateStops: intermediateStops,
);

const Alert _liftsOut = Alert(
  headerText: 'Lifts out of service',
  descriptionText: 'Use the ramp at the west end.',
);
const Alert _diverted = Alert(headerText: 'Diverted', descriptionText: null);
const Alert _blank = Alert(headerText: '', descriptionText: '');

void main() {
  group('collecting the alerts on a trip', () {
    test('takes them from the leg and from every stop', () {
      final leg = _leg(
        legAlerts: const [_liftsOut],
        intermediateStops: [
          _place('Middle', alerts: const [_diverted]),
        ],
      );
      final alerts = collectTripAlerts(leg, buildJourneyStops(leg));
      expect(
        alerts.map((a) => a.headerText),
        containsAll(<String>['Lifts out of service', 'Diverted']),
      );
    });

    test('says the same disruption once, however often it is attached', () {
      // Feeds routinely hang one alert off the leg and off each stop it
      // touches; three copies of "Lifts out of service" is not three warnings.
      final leg = _leg(
        legAlerts: const [_liftsOut],
        intermediateStops: [
          _place('Middle', alerts: const [_liftsOut]),
          _place('Later', alerts: const [_liftsOut]),
        ],
      );
      expect(collectTripAlerts(leg, buildJourneyStops(leg)), hasLength(1));
    });

    test('drops alerts with nothing to read', () {
      final leg = _leg(legAlerts: const [_blank]);
      expect(collectTripAlerts(leg, buildJourneyStops(leg)), isEmpty);
    });

    test('a trip with no alerts collects none', () {
      final leg = _leg();
      expect(collectTripAlerts(leg, buildJourneyStops(leg)), isEmpty);
    });
  });
}
