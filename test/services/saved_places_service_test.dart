import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/saved_place.dart';
import 'package:transportia/services/saved_places_service.dart';
import 'package:transportia/services/transitous_geocode_service.dart';

SavedPlace _place({
  required String name,
  String type = 'STOP',
  String? stopId,
  double lat = 52.5,
  double lon = 13.4,
  int? importance,
}) => SavedPlace(
  name: name,
  type: type,
  lat: lat,
  lon: lon,
  stopId: stopId,
  importance: importance ?? SavedPlacesService.initialImportance,
);

TransitousLocationSuggestion _suggestion({
  required String name,
  String? stopId,
  double lat = 52.5,
  double lon = 13.4,
}) => TransitousLocationSuggestion(
  id: 'geocoded-$name',
  stopId: stopId,
  name: name,
  lat: lat,
  lon: lon,
  type: 'STOP',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('remembering a picked place', () {
    test('the feed id is stored alongside it', () async {
      final updated = SavedPlacesService.recordSelection(
        bucket: SavedPlacesBucket.timetable,
        places: const [],
        suggestion: _suggestion(name: 'Ostkreuz', stopId: 'de-DELFI_stop:42'),
      );

      expect(updated.single.stopId, 'de-DELFI_stop:42');
    });

    test('picking again backfills an id onto a place stored without one', () {
      // Places kept before ids were recorded cannot open a departure board.
      // Choosing one from search is the moment its id becomes known, so it is
      // the moment to keep it — rather than leaving the entry dead forever.
      final before = [_place(name: 'Ostkreuz')];
      expect(before.single.stopId, isNull);

      final updated = SavedPlacesService.applySelection(
        before,
        _place(name: 'Ostkreuz', stopId: 'de-DELFI_stop:42'),
      );

      expect(updated, hasLength(1), reason: 'backfill must not duplicate');
      expect(updated.single.stopId, 'de-DELFI_stop:42');
    });

    test('a pick without an id does not erase one already stored', () {
      final before = [_place(name: 'Ostkreuz', stopId: 'de-DELFI_stop:42')];

      final updated = SavedPlacesService.applySelection(
        before,
        _place(name: 'Ostkreuz'),
      );

      expect(updated.single.stopId, 'de-DELFI_stop:42');
    });

    test('the id survives a save and load', () async {
      await SavedPlacesService.savePlaces(
        bucket: SavedPlacesBucket.timetable,
        places: [_place(name: 'Ostkreuz', stopId: 'de-DELFI_stop:42')],
      );

      final loaded = await SavedPlacesService.loadPlaces(
        bucket: SavedPlacesBucket.timetable,
      );

      expect(loaded.single.stopId, 'de-DELFI_stop:42');
    });

    test('a place stored before ids existed still reads', () {
      // 1.0.3 wrote no stopId; absent must mean null, not a failed decode.
      final place = SavedPlace.fromJson(const {
        'name': 'Ostkreuz',
        'type': 'STOP',
        'lat': 52.5,
        'lon': 13.4,
        'importance': 15,
      });

      expect(place, isNotNull);
      expect(place!.stopId, isNull);
    });
  });
}
