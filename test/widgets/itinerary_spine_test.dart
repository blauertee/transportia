import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/itinerary_detail_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:transportia/utils/time_utils.dart';

/// The guard on the redesign: moving the itinerary onto one spine was not
/// allowed to drop anything the leg cards used to print. Each test below names
/// a thing the old cards showed and checks it is still reachable.
final DateTime _t0 = DateTime(2026, 6, 1, 14, 30);

String _at(Duration offset) => _t0.add(offset).toUtc().toIso8601String();

Leg _ride() => Leg.fromJson({
  'mode': 'HIGHSPEED_RAIL',
  'startTime': _at(const Duration(minutes: 10)),
  'endTime': _at(const Duration(minutes: 60)),
  'scheduledStartTime': _at(const Duration(minutes: 8)),
  'scheduledEndTime': _at(const Duration(minutes: 58)),
  'duration': 3000,
  'headsign': 'Flughafen BER',
  'displayName': 'ICE 599',
  'routeLongName': 'Intercity-Express 599',
  'agencyName': 'Deutsche Bahn',
  'routeColor': '1A3D8F',
  'realTime': true,
  'interlineWithPreviousLeg': true,
  'distance': 41000.0,
  'tripId': 'trip-ice',
  'alerts': [
    {'headerText': 'Lift out of order', 'descriptionText': 'Use the stairs.'},
  ],
  'from': {
    'name': 'Berlin Hauptbahnhof',
    'lat': 52.525,
    'lon': 13.369,
    'stopId': 'stop-hbf',
    'track': '7',
  },
  'to': {
    'name': 'Flughafen BER',
    'lat': 52.366,
    'lon': 13.503,
    'stopId': 'stop-ber',
    'track': '3',
  },
  'intermediateStops': [
    {
      'name': 'Ostkreuz',
      'lat': 52.503,
      'lon': 13.469,
      'stopId': 'stop-ost',
      'track': '9',
      'scheduledArrival': _at(const Duration(minutes: 25)),
      'arrival': _at(const Duration(minutes: 27)),
      'scheduledDeparture': _at(const Duration(minutes: 28)),
      'departure': _at(const Duration(minutes: 30)),
    },
  ],
});

/// The short walk between two services the planner returns for a change.
Leg _change() => Leg.fromJson({
  'mode': 'WALK',
  'startTime': _at(const Duration(minutes: 3)),
  'endTime': _at(const Duration(minutes: 8)),
  'duration': 300,
  'distance': 260.0,
  'from': {
    'name': 'Naturkundemuseum',
    'lat': 52.53,
    'lon': 13.38,
    'stopId': 'stop-nat',
    'track': '2',
  },
  'to': {
    'name': 'Berlin Hauptbahnhof',
    'lat': 52.525,
    'lon': 13.369,
    'stopId': 'stop-hbf',
    'track': '7',
  },
});

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: WidgetsApp(
        color: const Color(0xFF000000),
        localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
        supportedLocales: const [Locale('en', 'US')],
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (_, _, _) => SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _noop({
  required String? stopId,
  required String stopName,
  required DateTime referenceTime,
}) {}

Future<void> _pumpRide(WidgetTester tester, {Leg? previous}) => _pump(
  tester,
  LegDetailsWidget(
    leg: _ride(),
    previousLeg: previous,
    openStopSheet: _noop,
    onShowOnMap: () {},
  ),
);

Future<void> _expand(WidgetTester tester) async {
  await tester.tap(find.text('Show stops'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('collapsed, the node still carries the old card front', () {
    testWidgets('the service badge and where it is going', (tester) async {
      await _pumpRide(tester);
      expect(find.text('ICE 599'), findsOneWidget);
      expect(find.text('Flughafen BER'), findsOneWidget);
    });

    testWidgets('the stop it leaves from, and its platform', (tester) async {
      await _pumpRide(tester);
      expect(find.text('Berlin Hauptbahnhof'), findsOneWidget);
      expect(find.text('Track 7'), findsOneWidget);
    });

    testWidgets('the departure time and its delay', (tester) async {
      await _pumpRide(tester);
      expect(
        find.text(formatTime(_t0.add(const Duration(minutes: 8)))),
        findsOneWidget,
      );
      expect(find.text('+2m'), findsOneWidget);
    });

    testWidgets('how long it takes and how far it goes', (tester) async {
      await _pumpRide(tester);
      expect(find.textContaining('50m'), findsOneWidget);
      expect(find.textContaining('41.00 km'), findsOneWidget);
    });

    testWidgets('that it has something wrong with it', (tester) async {
      // The triangle was on the old card and is the only warning until the
      // leg is opened.
      await _pumpRide(tester);
      expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
    });
  });

  group('expanded, the rest of the old card is there', () {
    testWidgets('the class of vehicle', (tester) async {
      await _pumpRide(tester);
      await _expand(tester);
      expect(find.textContaining('High-speed Train'), findsOneWidget);
    });

    testWidgets('the alert, in full', (tester) async {
      await _pumpRide(tester);
      await _expand(tester);
      expect(find.text('Lift out of order'), findsOneWidget);
      expect(find.text('Use the stairs.'), findsOneWidget);
    });

    testWidgets('every metadata chip the leg qualifies for', (tester) async {
      await _pumpRide(tester);
      await _expand(tester);
      expect(find.text('Real-time'), findsOneWidget);
      expect(find.text('Deutsche Bahn'), findsOneWidget);
      expect(find.text('Intercity-Express 599'), findsOneWidget);
      expect(find.text('Interlined'), findsOneWidget);
      expect(find.text('Delayed'), findsOneWidget);
    });

    testWidgets('each stop between, with both its times and its platform', (
      tester,
    ) async {
      await _pumpRide(tester);
      await _expand(tester);

      expect(find.text('Ostkreuz'), findsOneWidget);
      expect(
        find.text(formatTime(_t0.add(const Duration(minutes: 25)))),
        findsOneWidget,
      );
      expect(
        find.text(formatTime(_t0.add(const Duration(minutes: 28)))),
        findsOneWidget,
      );
      expect(find.text('Track 9'), findsOneWidget);
    });
  });

  testWidgets('a node shared with the leg before it shows both times', (
    tester,
  ) async {
    // The old screen printed the arrival on one card and the departure on the
    // next. One row now owns that point, so it has to print both or a time is
    // simply gone.
    final arrivesEarly = Leg.fromJson({
      'mode': 'WALK',
      'startTime': _at(const Duration(minutes: 1)),
      'endTime': _at(const Duration(minutes: 4)),
      'scheduledEndTime': _at(const Duration(minutes: 4)),
      'duration': 180,
      'from': {'name': 'Naturkundemuseum', 'lat': 52.53, 'lon': 13.38},
      'to': {'name': 'Berlin Hauptbahnhof', 'lat': 52.525, 'lon': 13.369},
    });

    await _pumpRide(tester, previous: arrivesEarly);

    // You get in at :34 and leave at :38 — the wait is the point.
    expect(
      find.text(formatTime(_t0.add(const Duration(minutes: 4)))),
      findsOneWidget,
    );
    expect(
      find.text(formatTime(_t0.add(const Duration(minutes: 8)))),
      findsOneWidget,
    );
  });

  testWidgets('a node reached and left at the same moment prints one time', (
    tester,
  ) async {
    await _pumpRide(tester, previous: _change());
    expect(
      find.text(formatTime(_t0.add(const Duration(minutes: 8)))),
      findsOneWidget,
    );
  });

  group('a change is its own stretch of the line', () {
    testWidgets('it says it is a change, and how long you have', (
      tester,
    ) async {
      await _pump(
        tester,
        TransferLegCard(leg: _change(), openStopSheet: _noop),
      );
      expect(find.textContaining('Change'), findsOneWidget);
      expect(find.textContaining('5m'), findsOneWidget);
    });

    testWidgets('it names the place and both platforms', (tester) async {
      await _pump(
        tester,
        TransferLegCard(leg: _change(), openStopSheet: _noop),
      );
      expect(find.text('Naturkundemuseum'), findsOneWidget);
      expect(find.text('Track 2 → Track 7'), findsOneWidget);
    });

    testWidgets('it keeps the walking distance the old card printed', (
      tester,
    ) async {
      await _pump(
        tester,
        TransferLegCard(leg: _change(), openStopSheet: _noop),
      );
      expect(find.textContaining('0.26 km walk'), findsOneWidget);
    });
  });

  group('the end of the line', () {
    testWidgets('names where you were going, which the old card did not', (
      tester,
    ) async {
      await _pump(
        tester,
        FinishLegCard(
          leg: _ride(),
          arrivalTime: _t0.add(const Duration(minutes: 60)),
          totalDuration: 3600,
          openStopSheet: _noop,
        ),
      );

      expect(find.text('Flughafen BER'), findsOneWidget);
      expect(find.textContaining('Finish'), findsOneWidget);
      expect(find.text('Track 3'), findsOneWidget);
    });
  });
}
