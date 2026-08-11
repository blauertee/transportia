# Repository Guidelines

## Project Structure & Module Organization
- `lib/`: application code.
  - `lib/main.dart`: entrypoint; boots `Transportia`.
  - `lib/app.dart`: app shell, routing, locale setup.
  - `lib/environment.dart`: app-wide constants and API version resolution.
  - `lib/api/`: Transitous (MOTIS) client — endpoint registry, HTTP client,
    query formatting. The only place that talks to `package:http`.
  - `lib/models/`: app-level models; `lib/models/transitous/` holds the
    response models mirroring the MOTIS schema.
  - `lib/screens/`: UI screens (e.g., `map_screen.dart`, `welcome_screen.dart`),
    with a subdirectory per screen large enough to be split up.
  - `lib/services/`: platform/data services (e.g., `location_service.dart`).
  - `lib/utils/`: pure helpers — no widgets, no `BuildContext`. Shared logic
    belongs here.
  - `lib/widgets/`: reusable UI components (e.g., `route_field_box.dart`),
    grouped into `journey/`, `map/`, `options/`, `search/`, `buttons/` and
    `skeletons/`.
  - `lib/providers/`, `lib/theme/`, `lib/constants/`, `lib/animations/`:
    app state, colours, preference keys, shared curves.
- `docs/`: audit trackers (`doc-contradictions.md`, `unused-code.md`).
- `Agenda.md`: what the code should look like — nesting, shared helpers, named
  constants, comments, and when a change needs a test.
- `assets/`: images and static assets (declared in `pubspec.yaml`).
- `test/`: Dart tests (`*_test.dart`).
- Platform runners: `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`.

## Build, Test, and Development Commands
- Install deps: `flutter pub get`
- Run app (auto‑select device): `flutter run`
  - Web example: `flutter run -d chrome`
- Static analysis: `flutter analyze`
- Format code: `dart format .` (CI-friendly check: `dart format . --set-exit-if-changed`)
- Unit tests: `flutter test`
- Coverage (optional): `flutter test --coverage`
- Release builds: `flutter build apk` | `flutter build ios` | `flutter build web`

## Coding Style & Naming Conventions
- Dart/Flutter style, 2-space indent; prefer `final`/`const` and trailing commas.
- File names: `snake_case.dart`. Screens: `*_screen.dart`; services: `*_service.dart`.
- Types: `UpperCamelCase`; members/functions/vars: `lowerCamelCase`.
- Avoid `print`; use logs or comments when necessary.
- Lints: `flutter_lints` configured via `analysis_options.yaml`. Fix all `flutter analyze` issues before submitting.
- See `Agenda.md` for the structural conventions: flattening nested branching
  into named methods, lifting duplicated logic into `lib/utils/` or
  `lib/widgets/`, naming non-obvious literals, and what to leave in a comment.

## Testing Guidelines
- Place tests in `test/` with `_test.dart` suffix (e.g., `route_field_box_test.dart`).
- Use `flutter_test`. Keep tests deterministic; mock location/permissions when needed.
- For API code, inject an `http.Client` into `TransitousClient` and drive it
  with `MockClient` from `package:http/testing.dart`. Parse tests should read
  the real captures in `test/fixtures/transitous/` rather than hand-written
  JSON; see the README there before re-capturing.
- Aim to cover core logic in `services/` and widget behaviors with golden or widget tests where practical.

## Commit & Pull Request Guidelines
- Commits: concise, imperative subject (e.g., “Improve welcome transition”).
- Group related changes; keep diffs focused. Reference issues if applicable.
- PRs must include:
  - Clear description and rationale.
  - Screenshots/GIFs for UI changes (Map/Welcome flows).
  - Test plan (commands run, devices/simulators tested).
  - Confirmation that `flutter analyze` passes and code is formatted.

## Security & Configuration Tips
- Do not commit secrets or keys. Manage platform permissions via `permission_handler` and update `AndroidManifest.xml`/`Info.plist` as needed.
- Keep `pubspec.yaml` assets in sync (e.g., `assets/images/welcome-image.png`).
