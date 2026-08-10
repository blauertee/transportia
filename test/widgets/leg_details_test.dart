import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/itinerary_detail_screen.dart';
import 'package:transportia/utils/time_utils.dart';

/// The card for one leg of a journey.
///
/// Collapsed it should carry what you have to act on — where the service is
/// going and which platform it leaves from — and only once opened the things
/// you look up: the class of vehicle, and every stop it calls at.
final DateTime _departure = DateTime(2026, 6, 1, 14, 30);

String _at(Duration offset) => _departure.add(offset).toUtc().toIso8601String();

/// A stop in the middle of the ride.
///
/// [wait] is how long the service stands there; zero means it only calls.
Map<String, dynamic> _stop({
  required String name,
  required Duration after,
  Duration wait = Duration.zero,
  Duration lateBy = Duration.zero,
  String? track,
}) {
  final arrival = after;
  final departure = after + wait;
  return {
    'name': name,
    'lat': 52.5,
    'lon': 13.4,
    'stopId': 'stop-${name.toLowerCase()}',
    if (track != null) 'track': track,
    'scheduledArrival': _at(arrival),
    'arrival': _at(arrival + lateBy),
    'scheduledDeparture': _at(departure),
    'departure': _at(departure + lateBy),
  };
}

Leg _leg({
  String mode = 'HIGHSPEED_RAIL',
  String? track,
  String headsign = 'Flughafen BER',
  List<Map<String, dynamic>> stops = const [],
}) {
  return Leg.fromJson({
    'mode': mode,
    'startTime': _at(Duration.zero),
    'endTime': _at(const Duration(minutes: 40)),
    'scheduledStartTime': _at(Duration.zero),
    'scheduledEndTime': _at(const Duration(minutes: 40)),
    'duration': const Duration(minutes: 40).inSeconds,
    'headsign': headsign,
    'routeShortName': 'ICE 599',
    // With a display name the row leads with the service badge; without one
    // the mode name is the title, which is a different path.
    'displayName': 'ICE 599',
    'from': {
      'name': 'Berlin Hauptbahnhof',
      'lat': 52.525,
      'lon': 13.369,
      'stopId': 'stop-from',
      if (track != null) 'track': track,
    },
    'to': {
      'name': 'Flughafen BER',
      'lat': 52.366,
      'lon': 13.503,
      'stopId': 'stop-to',
    },
    'intermediateStops': stops,
  });
}

Future<void> _pump(WidgetTester tester, Leg leg) async {
  tester.view.physicalSize = const Size(420, 1600);
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
          pageBuilder: (_, _, _) => SingleChildScrollView(
            child: LegDetailsWidget(
              leg: leg,
              openStopSheet:
                  ({
                    required String? stopId,
                    required String stopName,
                    required DateTime referenceTime,
                  }) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expand(WidgetTester tester) async {
  await tester.tap(find.text('Flughafen BER').first);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('collapsed, the row says where the service goes, not what '
      'class it is', (tester) async {
    await _pump(tester, _leg());

    expect(find.text('Flughafen BER'), findsOneWidget);
    expect(find.textContaining('High-speed Train'), findsNothing);
  });

  testWidgets('the class joins the note once the leg is open', (tester) async {
    await _pump(tester, _leg());
    await _expand(tester);

    // In the note line rather than beside the destination: it is a thing you
    // look up, not one you act on.
    expect(find.textContaining('High-speed Train'), findsOneWidget);
  });

  testWidgets('the node still names the stop it leaves from', (tester) async {
    // The name moved out of an endpoint row and onto the node itself, so it
    // has to still be there — and only once.
    await _pump(tester, _leg());
    expect(find.text('Berlin Hauptbahnhof'), findsOneWidget);
  });

  testWidgets('a leg with no headsign leaves no empty line', (tester) async {
    await _pump(tester, _leg(headsign: ''));

    expect(find.text('Berlin Hauptbahnhof'), findsOneWidget);
    expect(find.text(''), findsNothing);
  });

  testWidgets('the platform sits above the duration', (tester) async {
    await _pump(tester, _leg(track: '7'));

    expect(find.text('Track 7'), findsOneWidget);

    // Asserted by position, because "above the duration" is the request; a
    // track rendered anywhere on the card would pass a presence check.
    final track = tester.getRect(find.text('Track 7'));
    final duration = tester.getRect(find.text('40m'));
    expect(track.bottom, lessThanOrEqualTo(duration.top));
  });

  testWidgets('a train with no platform in the feed says so', (tester) async {
    await _pump(tester, _leg());

    // An absent platform on a train is a gap in the data, and the rider needs
    // to know it is missing rather than assume the card forgot to say.
    expect(find.text('Track —'), findsOneWidget);
  });

  testWidgets('a metro with no platform in the feed says so', (tester) async {
    await _pump(tester, _leg(mode: 'SUBWAY'));

    expect(find.text('Track —'), findsOneWidget);
  });

  testWidgets('a bus platform is shown when the feed gives one', (
    tester,
  ) async {
    // A bay number is as useful at a bus station as a platform is at a
    // terminus.
    await _pump(tester, _leg(mode: 'BUS', track: 'C4'));

    expect(find.text('Track C4'), findsOneWidget);
  });

  testWidgets('a bus with no platform is left alone', (tester) async {
    // Most buses have nothing to show, so a permanent grey dash would say
    // nothing at all.
    await _pump(tester, _leg(mode: 'BUS'));

    expect(find.text('Track —'), findsNothing);
    expect(find.textContaining('Track'), findsNothing);
  });

  testWidgets('a stop the service waits at shows both of its times', (
    tester,
  ) async {
    await _pump(
      tester,
      _leg(
        stops: [
          _stop(
            name: 'Ostkreuz',
            after: const Duration(minutes: 10),
            wait: const Duration(minutes: 3),
            lateBy: const Duration(minutes: 2),
          ),
        ],
      ),
    );
    await _expand(tester);

    expect(
      find.text(formatTime(_departure.add(const Duration(minutes: 10)))),
      findsOneWidget,
    );
    expect(
      find.text(formatTime(_departure.add(const Duration(minutes: 13)))),
      findsOneWidget,
    );
    // One delay against each, not one shared between them.
    expect(find.text('+2m'), findsNWidgets(2));
  });

  testWidgets('a stop the service only calls at shows one time', (
    tester,
  ) async {
    await _pump(
      tester,
      _leg(
        stops: [_stop(name: 'Ostkreuz', after: const Duration(minutes: 10))],
      ),
    );
    await _expand(tester);

    expect(
      find.text(formatTime(_departure.add(const Duration(minutes: 10)))),
      findsOneWidget,
    );
  });

  testWidgets("a stop's platform sits to the right of its name", (
    tester,
  ) async {
    await _pump(
      tester,
      _leg(
        stops: [
          _stop(
            name: 'Ostkreuz',
            after: const Duration(minutes: 10),
            track: '9',
          ),
        ],
      ),
    );
    await _expand(tester);

    final name = tester.getRect(find.text('Ostkreuz'));
    final track = tester.getRect(find.text('Track 9'));
    expect(track.left, greaterThan(name.right));
  });

  testWidgets('a stop with no platform leaves the column empty', (
    tester,
  ) async {
    // A dozen grey dashes down a timeline would be noise; the card above
    // already answers whether the one platform you stand on is known.
    await _pump(
      tester,
      _leg(
        track: '7',
        stops: [_stop(name: 'Ostkreuz', after: const Duration(minutes: 10))],
      ),
    );
    await _expand(tester);

    // The leg's own departure platform, once, on its node — and nothing at
    // all against Ostkreuz.
    expect(find.textContaining('Track'), findsOneWidget);
    expect(find.text('Track —'), findsNothing);
  });

  testWidgets('the platform is printed once, on the node it belongs to', (
    tester,
  ) async {
    await _pump(tester, _leg(track: '7'));
    await _expand(tester);

    // Opening the leg drops its stops onto the line; the leg's own first stop
    // is the ring above them and is not repeated among them.
    expect(find.text('Track 7'), findsOneWidget);
    expect(find.text('Berlin Hauptbahnhof'), findsOneWidget);
  });
}
