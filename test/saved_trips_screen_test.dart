import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/saved_trip.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/saved_trips_screen.dart';
import 'package:transportia/services/saved_trips_service.dart';
import 'package:transportia/widgets/saved_trip_card.dart';

SavedTrip _trip({required DateTime departure, required String to}) {
  final arrival = departure.add(const Duration(minutes: 15));
  final json =
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
                  'tripId': 'trip-$to',
                  'displayName': 'RE7',
                  'from': {
                    'name': 'Hauptbahnhof',
                    'lat': 52.525,
                    'lon': 13.369,
                  },
                  'to': {'name': to, 'lat': 52.366, 'lon': 13.503},
                },
              ],
            }),
          )
          as Map<String, dynamic>;
  return SavedTrip.fromItinerary(itinerary: Itinerary.fromJson(json));
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: const SavedTripsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SavedTripsService.savedTripsListenable.value = const [];
  });

  testWidgets('invites the user to save something when the list is empty', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('No saved trips yet'), findsOneWidget);
    expect(find.byType(SavedTripCard), findsNothing);
  });

  testWidgets('separates upcoming trips from past ones', (tester) async {
    await SavedTripsService.saveTrip(
      _trip(
        departure: DateTime.now().add(const Duration(days: 1)),
        to: 'Airport',
      ),
    );
    await SavedTripsService.saveTrip(
      _trip(
        departure: DateTime.now().subtract(const Duration(days: 1)),
        to: 'Ostkreuz',
      ),
    );

    await _pump(tester);

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.byType(SavedTripCard), findsNWidgets(2));
  });

  testWidgets('shows no Past heading when everything is still ahead', (
    tester,
  ) async {
    await SavedTripsService.saveTrip(
      _trip(
        departure: DateTime.now().add(const Duration(days: 1)),
        to: 'Airport',
      ),
    );

    await _pump(tester);

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Past'), findsNothing);
  });

  testWidgets('drops trips that finished long ago', (tester) async {
    await SavedTripsService.saveTrip(
      _trip(
        departure: DateTime.now().subtract(const Duration(days: 60)),
        to: 'Ostkreuz',
      ),
    );

    await _pump(tester);

    expect(find.text('No saved trips yet'), findsOneWidget);
    expect(await SavedTripsService.getSavedTrips(), isEmpty);
  });
}
