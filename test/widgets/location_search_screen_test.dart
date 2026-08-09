import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/screens/location_search_screen.dart';
import 'package:transportia/services/favorites_service.dart';
import 'package:transportia/services/saved_places_service.dart';

FavoritePlace _favourite({
  required String id,
  required String name,
  String? label,
  double lat = 52.5,
  double lon = 13.4,
}) => FavoritePlace(
  id: id,
  name: name,
  label: label,
  lat: lat,
  lon: lon,
  addedAt: DateTime.utc(2026, 1, 1),
);

Future<void> _keep(List<FavoritePlace> favourites) async {
  for (final favourite in favourites) {
    await FavoritesService.saveFavorite(favourite);
  }
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Pushed as a route rather than handed to WidgetsApp's builder, which sits
  // outside the Navigator: the screen focuses its field on open, and an
  // EditableText needs an Overlay to put its selection handles in.
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF000000),
      // The same delegates app.dart installs; showCupertinoDialog wants
      // CupertinoLocalizations for its barrier label.
      localizationsDelegates: const [
        DefaultWidgetsLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      onGenerateRoute: (settings) => PageRouteBuilder<void>(
        settings: settings,
        pageBuilder: (_, _, _) => const LocationSearchScreen(
          title: 'Destination',
          bucket: SavedPlacesBucket.search,
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

  testWidgets('favourites are there before a single character is typed', (
    tester,
  ) async {
    // The moment you want a favourite is when the field is empty; the old
    // dropdown deliberately withheld them until you started typing.
    await _keep([
      _favourite(id: 'a', name: 'Hauptbahnhof', label: 'Home'),
      _favourite(id: 'b', name: 'Alexanderplatz', lat: 52.52, lon: 13.41),
    ]);

    await _pump(tester);

    expect(find.text('FAVOURITES'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Alexanderplatz'), findsOneWidget);
  });

  testWidgets('a renamed place shows both names, an unrenamed one shows one', (
    tester,
  ) async {
    await _keep([
      _favourite(id: 'a', name: 'Hauptbahnhof', label: 'Home'),
      _favourite(id: 'b', name: 'Alexanderplatz', lat: 52.52, lon: 13.41),
    ]);

    await _pump(tester);

    // The alias leads, the searched name sits under it.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Hauptbahnhof'), findsOneWidget);
    // Nothing renamed here, so the name is not printed twice.
    expect(find.text('Alexanderplatz'), findsOneWidget);
  });

  testWidgets('an empty list says how to fill it', (tester) async {
    await _pump(tester);
    expect(find.text('Tap the heart on a place to keep it here.'), findsOne);
  });

  testWidgets('the map is offered as a way to answer', (tester) async {
    // Some places are easier to point at than to name.
    await _pump(tester);
    expect(find.bySemanticsLabel('Pick a point on the map'), findsOne);
  });

  testWidgets('a favourite offers its actions from the row and a long press', (
    tester,
  ) async {
    await _keep([_favourite(id: 'a', name: 'Hauptbahnhof')]);
    await _pump(tester);

    expect(find.bySemanticsLabel('Edit Hauptbahnhof'), findsOne);

    await tester.longPress(find.text('Hauptbahnhof'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Favourite'), findsOne);
    expect(find.text('Remove favourite'), findsOne);
  });

  testWidgets('renaming writes the alias and leaves the name alone', (
    tester,
  ) async {
    await _keep([_favourite(id: 'a', name: 'Hauptbahnhof')]);
    await _pump(tester);

    await tester.longPress(find.text('Hauptbahnhof'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Home');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = FavoritesService.favoritesListenable.value.single;
    expect(stored.label, 'Home');
    expect(stored.name, 'Hauptbahnhof');
    expect(stored.displayName, 'Home');
  });
}
