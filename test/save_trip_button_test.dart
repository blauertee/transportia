import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/saved_trip.dart';
import 'package:transportia/services/saved_trips_service.dart';
import 'package:transportia/widgets/save_trip_button.dart';

Itinerary _parsedItinerary(DateTime departure) {
  final arrival = departure.add(const Duration(minutes: 15));
  return Itinerary.fromJson(
    jsonDecode(
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
                'from': {'name': 'Hauptbahnhof', 'lat': 52.525, 'lon': 13.369},
                'to': {'name': 'Airport', 'lat': 52.366, 'lon': 13.503},
              },
            ],
          }),
        )
        as Map<String, dynamic>,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    OKToast(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
    ),
  );
}

/// The confirmation toast is registered with oktoast for a day, and that
/// timer outlives the visual auto-close. Run the clock past it so the test
/// binding does not tear the tree down with a timer still pending.
Future<void> _letToastExpire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(days: 2));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One fixed departure, so every itinerary built here is the *same*
  // connection and therefore resolves to the same saved-trip id.
  final departure = DateTime.now().add(const Duration(hours: 3));
  Itinerary itinerary() => _parsedItinerary(departure);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SavedTripsService.savedTripsListenable.value = const [];
  });

  testWidgets('saves and unsaves a connection', (tester) async {
    await _pump(tester, SaveTripButton(itinerary: itinerary()));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.bookmark), findsOneWidget);

    await tester.tap(find.byType(SaveTripButton));
    await tester.pumpAndSettle();
    await _letToastExpire(tester);

    expect(await SavedTripsService.getSavedTrips(), hasLength(1));
    expect(find.byIcon(LucideIcons.bookmarkCheck), findsOneWidget);

    await tester.tap(find.byType(SaveTripButton));
    await tester.pumpAndSettle();
    await _letToastExpire(tester);

    expect(await SavedTripsService.getSavedTrips(), isEmpty);
    expect(find.byIcon(LucideIcons.bookmark), findsOneWidget);
  });

  testWidgets('shows stored state on first build', (tester) async {
    await SavedTripsService.saveTrip(
      SavedTrip.fromItinerary(itinerary: itinerary()),
    );

    await _pump(tester, SaveTripButton(itinerary: itinerary()));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.bookmarkCheck), findsOneWidget);
  });

  testWidgets('renders nothing for an itinerary that cannot be stored', (
    tester,
  ) async {
    final unsaveable = Itinerary(
      duration: 60,
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(minutes: 1)),
      transfers: 0,
      legs: const [],
    );

    await _pump(tester, SaveTripButton(itinerary: unsaveable));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.bookmark), findsNothing);
    expect(find.byIcon(LucideIcons.bookmarkCheck), findsNothing);
  });
}
