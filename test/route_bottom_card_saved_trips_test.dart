import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/saved_trip.dart';
import 'package:transportia/models/time_selection.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/widgets/route_bottom_card.dart';
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

Future<void> _pumpCard(
  WidgetTester tester, {
  required List<SavedTrip> savedTrips,
  ValueChanged<SavedTrip>? onSavedTripTap,
  VoidCallback? onSeeAll,
}) async {
  final fromCtrl = TextEditingController();
  final toCtrl = TextEditingController();
  addTearDown(fromCtrl.dispose);
  addTearDown(toCtrl.dispose);
  final fromFocus = FocusNode();
  final toFocus = FocusNode();
  addTearDown(fromFocus.dispose);
  addTearDown(toFocus.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 900)),
          child: BottomCard(
            isCollapsed: false,
            collapseProgress: 0,
            onHandleTap: () {},
            onDragStart: () {},
            onDragUpdate: (_) {},
            onDragEnd: (_) {},
            fromCtrl: fromCtrl,
            toCtrl: toCtrl,
            fromFocusNode: fromFocus,
            toFocusNode: toFocus,
            showMyLocationDefault: true,
            onUnfocus: () {},
            onSwapRequested: () => true,
            routeFieldLink: LayerLink(),
            fromLoading: false,
            toLoading: false,
            fromSelection: null,
            toSelection: null,
            onSearch: (_) {},
            timeSelectionLayerLink: LayerLink(),
            onTimeSelectionTap: () {},
            timeSelection: TimeSelection.now(),
            recentTrips: const [],
            onRecentTripTap: (_) {},
            savedTrips: savedTrips,
            onSavedTripTap: onSavedTripTap ?? (_) {},
            onSeeAllSavedTrips: onSeeAll ?? () {},
            favorites: const [],
            onFavoriteTap: (_) {},
            hasLocationPermission: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ThemeProvider reads preferences as soon as it is constructed.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('hides the section when nothing is saved', (tester) async {
    await _pumpCard(tester, savedTrips: const []);

    expect(find.text('Saved trips'), findsNothing);
  });

  testWidgets('shows at most three upcoming trips and offers the rest', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pumpCard(
      tester,
      savedTrips: [
        for (var i = 1; i <= 5; i++)
          _trip(
            departure: now.add(Duration(hours: i)),
            to: 'Stop $i',
          ),
      ],
    );

    expect(find.text('Saved trips'), findsOneWidget);
    expect(find.byType(SavedTripCard), findsNWidgets(3));
    expect(find.text('See all (2 more)'), findsOneWidget);
  });

  testWidgets('keeps finished trips out of the way', (tester) async {
    final now = DateTime.now();
    await _pumpCard(
      tester,
      savedTrips: [
        _trip(departure: now.subtract(const Duration(days: 2)), to: 'Old'),
        _trip(departure: now.add(const Duration(hours: 2)), to: 'Airport'),
      ],
    );

    expect(find.byType(SavedTripCard), findsOneWidget);
    expect(find.text('Airport'), findsOneWidget);
    expect(find.text('Old'), findsNothing);
  });

  testWidgets('hides the section when every saved trip is in the past', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      savedTrips: [
        _trip(
          departure: DateTime.now().subtract(const Duration(days: 2)),
          to: 'Old',
        ),
      ],
    );

    expect(find.text('Saved trips'), findsNothing);
  });

  testWidgets('reports taps on a trip and on See all', (tester) async {
    SavedTrip? tapped;
    var seeAll = 0;
    final trip = _trip(
      departure: DateTime.now().add(const Duration(hours: 2)),
      to: 'Airport',
    );

    await _pumpCard(
      tester,
      savedTrips: [trip],
      onSavedTripTap: (t) => tapped = t,
      onSeeAll: () => seeAll++,
    );

    await tester.tap(find.byType(SavedTripCard));
    await tester.tap(find.text('See all'));

    expect(tapped?.id, trip.id);
    expect(seeAll, 1);
  });
}
