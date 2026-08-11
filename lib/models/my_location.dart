import '../services/transitous_geocode_service.dart';
import 'route_field_kind.dart';

/// What the app calls the rider's current position.
///
/// The origin field leaves itself empty for this and resolves the position at
/// search time, so the trip is planned from where you are when you press
/// Search rather than where you were when you picked.
const String myLocationName = 'My Location';

/// The answer the picker returns for it — recognised by id, so a place that
/// happens to share the name is not mistaken for it.
final TransitousLocationSuggestion myLocationSuggestion =
    TransitousLocationSuggestion(
      id: 'my-location',
      name: myLocationName,
      lat: 0,
      lon: 0,
      type: 'PLACE',
    );

/// The rider's position as a pickable place, once it is actually known.
///
/// [myLocationSuggestion] is the token the picker returns; it carries no
/// coordinates because the picker has none. This is what the caller turns it
/// into once it has a fix, keeping the same id so a later reader can still
/// tell it from a geocoded place that happens to be nearby.
TransitousLocationSuggestion myLocationAt(double lat, double lon) =>
    TransitousLocationSuggestion(
      id: myLocationSuggestion.id,
      name: myLocationName,
      lat: lat,
      lon: lon,
      type: 'PLACE',
    );

/// What picking My Location means for a field.
///
/// The origin takes null: an empty origin already means "from where I am" and
/// is resolved when Search is pressed, so the trip starts where you are then
/// rather than where you were when you picked. The destination cannot do that
/// — the search rejects an empty destination — so it takes the fix as it
/// stands.
TransitousLocationSuggestion? myLocationSelectionFor(
  RouteFieldKind field,
  double lat,
  double lon,
) => field == RouteFieldKind.from ? null : myLocationAt(lat, lon);
