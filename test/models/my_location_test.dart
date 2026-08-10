import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/my_location.dart';
import 'package:transportia/models/route_field_kind.dart';

/// Picking "My Location" means two different things depending on which end of
/// the trip it is for, and getting that backwards is a silent failure: an
/// origin that was pinned to a stale coordinate, or a destination the search
/// rejects as empty.
void main() {
  test('an origin is left for the search to resolve', () {
    // An empty origin already means "from where I am", read when Search is
    // pressed — so the trip starts where you are then, not where you were
    // when you picked.
    expect(myLocationSelectionFor(RouteFieldKind.from, 52.52, 13.41), isNull);
  });

  test('a destination takes the position as it stands', () {
    // The planner rejects an empty destination outright, so this end has to
    // carry real coordinates.
    final selection = myLocationSelectionFor(RouteFieldKind.to, 52.52, 13.41);

    expect(selection, isNotNull);
    expect(selection!.lat, 52.52);
    expect(selection.lon, 13.41);
    expect(selection.name, myLocationName);
  });

  test('a resolved position is still recognisable as My Location', () {
    // Recognised by id rather than by name, so a stop that happens to be
    // called "My Location" is not mistaken for it.
    expect(myLocationAt(52.52, 13.41).id, myLocationSuggestion.id);
  });
}
