import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/saved_trip.dart';
import 'package:transportia/models/time_selection.dart';
import 'package:transportia/services/itinerary_refresh_service.dart';
import 'package:transportia/widgets/saved_trip_card.dart';

import 'support/plan_fixtures.dart';

SavedTrip _trip({
  required DateTime departure,
  String? label,
  bool cancelled = false,
}) {
  return SavedTrip.fromItinerary(
    itinerary: Itinerary.fromJson(
      planItineraryJson(departure: departure, cancelled: cancelled),
    ),
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

    expect(find.text('S+U Berlin Hauptbahnhof'), findsOneWidget);
    expect(find.text('Flughafen BER'), findsOneWidget);
    expect(find.text('RE7'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^in \d')), findsOneWidget);
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
    expect(
      find.text('S+U Berlin Hauptbahnhof → Flughafen BER'),
      findsOneWidget,
    );
  });

  testWidgets('marks a finished trip as completed rather than counting down', (
    tester,
  ) async {
    final departure = DateTime.now().subtract(const Duration(days: 1));
    await _pump(tester, SavedTripCard(trip: _trip(departure: departure)));

    expect(find.text('Completed'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^in \d')), findsNothing);
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
