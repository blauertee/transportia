# Documentation that disagrees with the code

Places where a document, a doc comment or a README states something the
implementation does not do. Each entry says what is written, what is true, and
which of the two looks wrong.

Tick an entry off by fixing one side and deleting the row. Nothing here has
been changed yet — resolving a contradiction is a decision about intent, not a
cleanup.

Last swept: 2026-08-11, against `c4fa8bc`.

---

## 1. `AGENTS.md` names an asset that does not exist

- **Written** — "Keep `pubspec.yaml` assets in sync (e.g.,
  `assets/images/welcome-image.png`)."
- **True** — the file is `assets/images/welcome-image.webp`. That is what
  `pubspec.yaml:56` declares and what `welcome_screen.dart:125` loads. There is
  no `.png`.
- **Wrong side** — the document. A one-word fix, but the example is the only
  concrete thing that line says, so it is worth it being right.

## 2. `AGENTS.md`'s module map is missing half of `lib/`

- **Written** — `lib/` contains `main.dart`, `app.dart`, `api/`,
  `models/transitous/`, `screens/`, `services/`, `widgets/`.
- **True** — it also contains `animations/`, `constants/`, `providers/`,
  `theme/`, `utils/`, `environment.dart`, and `models/` holds a dozen
  app-level models outside `models/transitous/`. `utils/` in particular is
  where shared logic is expected to go, and the map never mentions it.
  `screens/` and `widgets/` also have subdirectories (`screens/map_screen/`,
  `screens/transit_options/`, `widgets/journey/`, `widgets/map/`,
  `widgets/options/`, `widgets/search/`, `widgets/buttons/`,
  `widgets/skeletons/`) that the flat description does not suggest.
- **Wrong side** — the document. An agent reading only `AGENTS.md` would not
  know `lib/utils/` is the place for a shared helper.

## 3. `AGENTS.md` says avoid `print`; the code logs with `debugPrint`

- **Written** — "Avoid `print`; use logs or comments when necessary."
- **True** — there is no `print` anywhere in `lib/`, so the rule is being
  followed. But "logs" is ambiguous: the code uses both `debugPrint` (10 sites,
  mostly in `itinerary_detail_screen.dart` and `map_screen.dart`) and
  `dart:developer`'s `log` (in `routing_options_service.dart` and
  `itinerary.dart`).
- **Wrong side** — arguably neither, but the guidance does not say which of the
  two to reach for, and the codebase has not picked one. Worth deciding.

## 4. `README.md` points bug reports at a repository that is not this one

- **Written** — "Please open a GitHub issue:
  `https://github.com/Wafler1/transportia/issues/new/choose`".
- **True** — `origin` is `https://github.com/blauertee/transportia`.
- **Wrong side** — unknown, and that is the point. Either the README is stale
  or this is a fork whose README was never repointed. Someone with the history
  should say which.

## 5. `AGENTS.md` names an example test file that does not exist

- **Written** — "Place tests in `test/` with `_test.dart` suffix (e.g.,
  `route_field_box_test.dart`)."
- **True** — there is no `route_field_box_test.dart`, and
  `lib/widgets/route_field_box.dart` (530 lines) has no direct test at all. The
  example was presumably aspirational.
- **Wrong side** — both, in different ways. Either pick an example that exists,
  or write the test the example implies.

## 6. `_legacyModeOptionCount` describes a count that no longer bounds anything

- **Written** — `routing_options_service.dart`: "Size of the mode list the
  previous Transit options screen offered", `static const int
  _legacyModeOptionCount = 28`, used as `modes.length >= 28 ? const [] : modes`
  to mean "everything was selected, so send no restriction".
- **True** — `TransitMode` now has 33 values. A stored selection of 28, 29, 30,
  31 or 32 modes is a deliberately narrowed set, and it is silently widened to
  "no restriction".
- **Wrong side** — the implementation, but only for data written by old builds,
  which is the only data this path reads. Whether that window is worth closing
  depends on how many modes the old screen really offered — the comment is the
  only surviving record of it. Worth confirming before touching, because
  getting it wrong silently changes what people get back from a search.

## 7. `SavedTripsService`'s class doc undersells what it does

- **Written** — "there is no cap and nothing is evicted to make room — a saved
  trip disappears only when the user removes it, or once it is long enough in
  the past to be clutter."
- **True** — accurate, and `_keepPastTripsFor = Duration(days: 30)` is the
  "long enough". The doc never gives the figure, so a reader has to find the
  constant to learn a saved trip is dropped after a month.
- **Wrong side** — the document, mildly. Naming the window in the class doc
  would make the one surprising behaviour discoverable.

---

## Checked and found consistent

Recorded so the next sweep does not re-verify them:

- `AGENTS.md`: "`lib/api/` … the only place that talks to `package:http`" —
  true, `transitous_client.dart` is the sole importer.
- `test/fixtures/transitous/README.md`'s trimming claims — all four hold
  exactly: `map_routes.json` has 1 route / 3 polylines / 5 stops,
  `one_to_all.json` has 30 entries, `map_stops.json` has 20,
  `debug_transfers.json` has 5 equivalences and 15 transfers.
- `changeover.dart`: "Ten minutes is room to read the screen and walk" matches
  `kReplanHeadStart = Duration(minutes: 10)`.
- `SavedTripsService.getSavedTrips` — "soonest departure first" matches
  `_sort`.
- `transitous_endpoint.dart` — the six `prefKey`s the doc says must not change
  (`plan`, `trip`, `stoptimes`, `mapTrips`, `mapStops`, `geocode`) are all
  present and spelled as stated.
