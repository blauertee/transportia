import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/saved_place.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/timetables_screen.dart';
import 'package:transportia/services/favorites_service.dart';
import 'package:transportia/services/saved_places_service.dart';

FavoritePlace _favourite({
  required String id,
  required String name,
  String type = 'STOP',
  String? label,
  double lat = 52.5,
  double lon = 13.4,
}) => FavoritePlace(
  id: id,
  name: name,
  label: label,
  type: type,
  lat: lat,
  lon: lon,
  addedAt: DateTime.utc(2026, 1, 1),
);

SavedPlace _stop({
  required String name,
  String type = 'STOP',
  double lat = 52.52,
  double lon = 13.41,
}) => SavedPlace(
  name: name,
  type: type,
  lat: lat,
  lon: lon,
  importance: SavedPlacesService.initialImportance,
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: WidgetsApp(
        color: const Color(0xFF000000),
        localizationsDelegates: const [
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (_, _, _) => const TimetablesScreen(),
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
    FavoritesService.favoritesListenable.value = const [];
  });

  testWidgets('with nothing remembered it still says what to do', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Search for a stop'), findsOneWidget);
  });

  testWidgets('recent stops are offered before anything is searched for', (
    tester,
  ) async {
    // Choosing a stop is what this screen is for, and the stops already
    // picked here are the likeliest answers.
    await SavedPlacesService.savePlaces(
      bucket: SavedPlacesBucket.timetable,
      places: [_stop(name: 'Alexanderplatz'), _stop(name: 'Hauptbahnhof')],
    );

    await _pump(tester);

    expect(find.text('RECENT STOPS'), findsOneWidget);
    expect(find.text('Alexanderplatz'), findsOneWidget);
    expect(find.text('Hauptbahnhof'), findsOneWidget);
    expect(find.text('Search for a stop'), findsNothing);
  });

  testWidgets('a remembered place that is not a stop is left out', (
    tester,
  ) async {
    // The screen can only open departures for a stop, so anything else would
    // be a dead end.
    await SavedPlacesService.savePlaces(
      bucket: SavedPlacesBucket.timetable,
      places: [_stop(name: 'Somewhere', type: 'ADDRESS')],
    );

    await _pump(tester);

    expect(find.text('Somewhere'), findsNothing);
    expect(find.text('Search for a stop'), findsOneWidget);
  });

  testWidgets('favourite stations appear, and only the stations', (
    tester,
  ) async {
    await FavoritesService.saveFavorite(
      _favourite(id: 'a', name: 'Ostkreuz', label: 'Home'),
    );
    await FavoritesService.saveFavorite(
      _favourite(id: 'b', name: 'A street', type: 'ADDRESS', lat: 52.1),
    );

    await _pump(tester);

    expect(find.text('FAVOURITE STOPS'), findsOneWidget);
    // The alias leads, the searched name sits under it.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Ostkreuz'), findsOneWidget);
    expect(find.text('A street'), findsNothing);
  });

  testWidgets('no favourite station means no favourites section', (
    tester,
  ) async {
    await FavoritesService.saveFavorite(
      _favourite(id: 'b', name: 'A street', type: 'ADDRESS'),
    );

    await _pump(tester);

    expect(find.text('FAVOURITE STOPS'), findsNothing);
  });
}
