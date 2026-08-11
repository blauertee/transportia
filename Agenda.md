# Agenda

Standing guidance for keeping this codebase readable. These are the rules a
cleanup pass works to; they apply to new code as it is written, which is
cheaper than sweeping for them later.

`AGENTS.md` covers how to build, test and format. This file covers what the
code should look like once it does.

---

## Flatten nested branching into named methods

A conditional nested three deep inside a `build` is a paragraph with no topic
sentence. Give the question a name and let the call site read as the answer.

```dart
// Before: what does this decide?
if (_currentIndex == 0) {
  if (overlaysVisible) {
    visibility = 0.0;
  } else {
    if (progress <= hideStart) {
      visibility = 1.0;
    } else if (progress >= hideEnd) {
```

```dart
// After
visibility: _navBarVisibility(progress: progress, overlaysVisible: overlaysVisible),
```

Practically:

- **Prefer guard clauses.** Four early returns beat one nested chain. Each line
  states a case and leaves; nothing has to be held in mind.
- **A `build` deeper than about eight levels wants splitting** — into a private
  method for a section, or a `StatelessWidget` for a piece with its own props.
  The timetable screen's header and stop controls are methods for this reason.
- **Never dispatch on a running index.** A `SliverChildBuilderDelegate` that
  works out which card index 4 means by comparing it against counts derived
  from each other is unmaintainable the moment a card is added. Build a list of
  section builders and index into it; each card is then described where it is
  added.
- **Name the boolean, not just the branch.** `if (position.isAtStop)` says what
  is being asked. `if (a && b && i == c && i < d - 1)` does not.

## Lift duplicated logic into `lib/`

The duplication worth hunting is the kind that lives in two files that never
mention each other. Two screens drawing the same trip, two modals with the same
animation, three copies of a chip. Finding it is usually a side effect of the
step above: once both copies are named methods, they turn out to have the same
name.

Where it goes:

- **`lib/utils/`** for pure functions and small value types — anything with no
  `BuildContext` and no widgets. `vehicle_position.dart` is the model: a
  computation plus the questions callers ask of its result. This is where a
  helper is testable without pumping a widget, so put it here when you can.
- **`lib/widgets/`** for shared UI. Give a scaffold the parts that differ as
  parameters (`MapSelectionModal` takes its entry scale and card padding); give
  a variant its own named constructor (`SelectableTick.large`,
  `AlertNotice.compact`) rather than a pile of optional arguments at every call.
- **`lib/models/`** when the duplication is really a missing type. If two places
  compute the same thing from the same fields, the answer often belongs on the
  model.

When the two copies have drifted, **unify on the better behaviour and say so in
the commit.** The map's trip card knew where a vehicle was more precisely than
Connection Info did; merging them meant Connection Info got better, which is a
change worth naming rather than burying.

## Name any literal that is not self-evident

The test is whether a reader can tell what the number means without leaving the
line.

Name it when it is a threshold, an interval, a limit, a conversion factor, a
tolerance, a count, or an index with meaning:

```dart
static const double _kSheetFlingVelocity = 700.0;   // px/s: flung, not placed
const Duration _kSearchDebounce = Duration(milliseconds: 220);
static const double _caloriesPerWalkedKilometre = 50;
const int kNoStopIndex = -1;
```

Leave it inline when it is a dimension in a widget tree — `SizedBox(height: 12)`,
`fontSize: 14`, `EdgeInsets.all(16)`. Those read fine in place, and naming every
one of them turns a layout into a lookup table. The exception is a dimension two
things must agree on: if a marker's size and the gap cut for it must match, name
it once.

Put the constant where it is used: file-level `_k…` for one file, a `static
const` on the class for one class, `lib/theme/` for something the whole app
shares.

## Delete comments that describe the past

A comment explaining why the code is what it is, is worth its space. A comment
explaining what the code used to be is not — the reader has no way to check it,
and it describes a program that no longer exists.

Strip the archaeology, keep the rule:

```dart
// Before
/// A 300m walk across a station used to render as an ordinary walk simply
/// because it cleared a 35m threshold, which said nothing a rider wanted
/// to know.

// After
/// Getting between two services is one act to the traveller — the question
/// is "have I time, and which platform", not "how far".
```

**Keep** comments about constraints that are still live, even when they sound
historical. `routing_options_service.dart` explains that it reads settings older
builds wrote; those settings are still on people's phones, so that is a fact
about today. The test is whether the reader could act on it.

## Write a test when the change is deep

A rename does not need a test. Any of these do:

- **Logic extracted to `lib/utils/`.** It is now testable without a widget,
  which was most of the point. `estimateVehiclePosition` had no coverage while
  it was two copies of a method inside two screens.
- **Two implementations merged into one.** The test is what says which
  behaviour won.
- **Anything with an index, a boundary, or a clock.** Cover before, at, and
  after: before departure, the departure minute itself, mid-run, and after
  arrival. The minute boundary is where a rewrite quietly changes meaning.
- **The empty and the degenerate case.** No stops, no times, one item, an index
  past the end. These are where the old code had latent crashes.

Fix the clock rather than reading it — take `DateTime? now` and pass it in.
Tests that call `DateTime.now()` pass at 10:00 and fail at midnight.

## Keep the audit trackers current

Two files under `docs/` hold findings that are not safe to act on unilaterally:

- **`docs/doc-contradictions.md`** — where a document and the code disagree.
  Fixing one requires knowing which side was meant, so entries are recorded
  rather than resolved. It also lists what was checked and found consistent, so
  the next sweep does not re-verify it.
- **`docs/unused-code.md`** — public declarations nothing references, each with
  a judgement on whether it reads as an API waiting for its caller or as
  something finished with. Most unused code here is the former.

Both are stamped with the commit they were swept against. When you resolve an
entry, delete the row; when you sweep again, update the stamp.

---

## Verifying a pass

```
flutter analyze          # must be clean, not merely no-worse
flutter test             # every test, not the ones you touched
dart format .            # or --set-exit-if-changed in CI
```

A refactor that keeps the tests green while the analyzer is dirty has not
finished. Run all three before each commit, not once at the end — it is the
only way to know which change broke something.
