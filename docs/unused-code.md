# Code nothing calls

Declarations in `lib/` with no reference anywhere in `lib/` or `test/`. Each
entry says what it is and whether it is worth keeping.

Nothing here has been deleted. Some of it is a public API waiting for its
caller and some is genuinely finished with, and the two look identical from a
reference count — the judgement column is the point of the file.

`flutter analyze` already reports unused *private* members, and reports none;
everything below is public, which is why it goes unflagged.

Last swept: 2026-08-11, against `8020837`.

---

## Likely to be wanted again — keep

### `RoutingService.findRoutes` — `lib/services/routing_service.dart:13`

The unpaginated form of a search: calls `findRoutesPaginated` and hands back
just the itineraries. Every current caller wants the cursors, so nobody uses
it.

**Judgement:** keep. It is three lines over the method beside it, and any
caller that wants one page of results — a deep link, a widget, a test —
reaches for exactly this shape. Deleting it saves nothing and the next person
writes it again.

### `TransitPlace.effectiveArrival` / `effectiveDeparture` — `lib/models/transitous/place.dart:97,100`

"Real-time if we have it, scheduled otherwise." The pattern is written out by
hand in several places instead (`stop.departure ?? stop.arrival` in the trip
timeline, `stopTime.place.arrival ?? stopTime.place.scheduledArrival` in the
stop modal).

**Judgement:** keep, and start using them. These are not unused so much as
un-adopted — the fallback they express is repeated at four or five call sites
that could just call the getter. This one is a refactor waiting to happen
rather than dead weight.

### `Alert.isInEffectAt` — `lib/models/transitous/alert.dart:59`

Whether an alert's impact period covers a given moment.

**Judgement:** keep. Alerts are currently shown whenever the feed attaches
them, which means a rider can be warned about a disruption that ended last
Tuesday. Filtering by impact period is the obvious next step and this is the
predicate for it.

### `RentalVehicle.isAvailable` — `lib/models/transitous/rentals_response.dart:211`

`!isReserved && !isDisabled`.

**Judgement:** keep. The rentals layer draws every vehicle the feed returns,
including ones nobody can take. The moment that is filtered, this is the
filter.

### `Match.addressLine` — `lib/models/transitous/match.dart:134`

Street and house number joined, guarding both empty cases.

**Judgement:** keep. Search results currently show the raw `name`; showing an
address line for address matches is a small, likely improvement, and the
null-handling here is the fiddly part of it.

### `FavoritesService.isFavorite` — `lib/services/favorites_service.dart:206`

Membership test by id.

**Judgement:** borderline, lean keep. `map_screen.dart` answers the same
question with its own `_isFavourite(selection)` against its in-memory list,
which is the right thing on that screen — it must not hit storage per frame.
But any screen without that cached list needs this. Cheap to keep.

### `Environment.planApiVersion` and its five siblings — `lib/environment.dart`

`planApiVersion`, `tripApiVersion`, `stopTimesApiVersion`, `mapTripsApiVersion`,
`mapStopsApiVersion`, `geocodeApiVersion` — each is
`versionFor(TransitousEndpoint.x)`.

**Judgement:** delete the six, keep `versionFor`. They were the API before
`TransitousEndpoint` existed, and every caller now goes through
`versionFor`/`pathFor` directly. Six named getters that each wrap one enum
lookup is a second way to ask the same question, and a seventh endpoint will
not get one. The developer info screen already enumerates
`TransitousEndpoint.values` rather than listing these.

---

## Probably finished with — candidates for deletion

### `FavoritesService.reorderFavorites` — `lib/services/favorites_service.dart:152`

Persists a caller-supplied ordering wholesale. Its `try`/`catch (e) { rethrow; }`
does nothing, which suggests it was written alongside a drag-to-reorder UI
that never shipped.

**Judgement:** could go, but only once someone confirms reordering favourites
is not on the roadmap. Favourites currently sort by insertion, and a
hand-ordered list is a very ordinary thing to want. If it stays, the pointless
`try`/`catch` should go.

### `RecentTripsService.clearHistory` — `lib/services/recent_trips_service.dart:46`

Wipes the recent-trips key.

**Judgement:** keep, and wire it up. There is no way for a user to clear their
recent trips anywhere in Settings, which for a list of places someone has
searched for is closer to a gap than to a missing feature. The method is the
easy half of that.

### `parseHexColorOr` — `lib/utils/color_utils.dart:22`

`parseHexColor(hex) ?? fallback`. Sits between `parseHexColor` (used widely)
and `parseHexColorOrAccent` (used widely).

**Judgement:** delete. Callers either want the accent fallback — for which
there is a function they already use — or want to spell `?? something` at the
call site, which every one of them does. The middle rung of the ladder has no
users and reads no better than the `??` it hides.

### The no-op unfocus debounce — `lib/screens/map_screen.dart:4084`

Not an unused declaration but dead work. When neither route field has focus,
`_applyFocusState` starts a 100ms timer whose callback is:

```dart
if (!mounted) return;
if (!_fromFocus.hasFocus && !_toFocus.hasFocus) {}
```

An empty `if` body. The timer is created, stored, cancelled in three places
and disposed of, and does nothing at any point. The surrounding early `return`
is what actually matters.

**Judgement:** delete the timer and keep the `return`. The empty body reads
like something was removed and its scaffolding left behind; there is no future
in which an if-statement with no body is what was wanted. Worth a moment
first to check the branch is meant to be a no-op at all, since the alternative
reading is that a behaviour went missing here.
