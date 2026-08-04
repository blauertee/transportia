import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/saved_trip.dart';
import 'package:transportia/models/time_selection.dart';
import 'package:transportia/services/itinerary_refresh_service.dart';
import 'package:transportia/widgets/saved_trip_card.dart';

Map<String, dynamic> _planJson({
  required DateTime departure,
  bool cancelled = false,
}) {
  final arrival = departure.add(const Duration(minutes: 15));
  return jsonDecode(
        jsonEncode({
          'duration': 900,
          'startTime': departure.toUtc().toIso8601String(),
          'endTime': arrival.toUtc().toIso8601String(),
          'transfers': 0,
          'legs': [
            {
              'mode': 'RAIL',
              'startTime': departure.toUtc().toIso8601String(),
              'endTime': arrival.toUtc().toIso8601String(),
              'duration': 900,
              'tripId': 'trip-re7',
              'displayName': 'RE7',
              'cancelled': cancelled,
              'from': {'name': 'Hauptbahnhof', 'lat': 52.525, 'lon': 13.369},
              'to': {'name': 'Airport', 'lat': 52.366, 'lon': 13.503},
            },
          ],
        }),
      )
      as Map<String, dynamic>;
}

SavedTrip _trip({
  required DateTime departure,
  String? label,
  bool cancelled = false,
}) {
  return SavedTrip.fromItinerary(
    itinerary: Itinerary.fromJson(
      _planJson(departure: departure, cancelled: cancelled),
    ),
    fromName: 'Hauptbahnhof',
    fromLat: 52.525,
    fromLon: 13.369,
    toName: 'Airport',
    toLat: 52.366,
    toLon: 13.503,
    timeSelection: TimeSelection(dateTime: departure, isArriveBy: false),
    label: label,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Align(alignment: Alignment.topCenter, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the route and a countdown for an upcoming trip', (
    tester,
  ) async {
    final departure = DateTime.now().add(const Duration(hours: 2));
    await _pump(tester, SavedTripCard(trip: _trip(departure: departure)));

    expect(find.text('Hauptbahnhof'), findsOneWidget);
    expect(find.text('Airport'), findsOneWidget);
    expect(find.text('RE7'), findsOneWidget);
    expect(find.textContaining('in '), findsOneWidget);
  });

  testWidgets('prefers a user label and still shows the route', (tester) async {
    final departure = DateTime.now().add(const Duration(hours: 2));
    await _pump(
      tester,
      SavedTripCard(
        trip: _trip(departure: departure, label: 'Airport run'),
      ),
    );

    expect(find.text('Airport run'), findsOneWidget);
    expect(find.text('Hauptbahnhof → Airport'), findsOneWidget);
  });

  testWidgets('marks a finished trip as completed rather than counting down', (
    tester,
  ) async {
    final departure = DateTime.now().subtract(const Duration(days: 1));
    await _pump(tester, SavedTripCard(trip: _trip(departure: departure)));

    expect(find.text('Completed'), findsOneWidget);
    expect(find.textContaining('in '), findsNothing);
  });

  testWidgets('surfaces a cancelled leg from the stored snapshot', (
    tester,
  ) async {
    final departure = DateTime.now().add(const Duration(hours: 2));
    await _pump(
      tester,
      SavedTripCard(trip: _trip(departure: departure, cancelled: true)),
    );

    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('surfaces a cancellation reported by a refresh', (tester) async {
    final departure = DateTime.now().add(const Duration(hours: 2));
    await _pump(
      tester,
      SavedTripCard(
        trip: _trip(departure: departure),
        freshness: ItineraryFreshness.changed,
      ),
    );

    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('reports taps and long presses', (tester) async {
    var tapped = 0;
    var longPressed = 0;
    final departure = DateTime.now().add(const Duration(hours: 2));

    await _pump(
      tester,
      SavedTripCard(
        trip: _trip(departure: departure),
        onTap: () => tapped++,
        onLongPress: () => longPressed++,
      ),
    );

    await tester.tap(find.byType(SavedTripCard));
    await tester.longPress(find.byType(SavedTripCard));

    expect(tapped, 1);
    expect(longPressed, 1);
  });
}
