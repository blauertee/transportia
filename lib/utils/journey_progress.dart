/// How much of a stretch of the spine is drawn as already travelled.
///
/// Pale rather than invisible: the journey behind you is still the journey,
/// and a rider checking which station they left wants to read it.
const double kTravelledOpacity = 0.3;

/// How far along a journey the clock says the traveller is.
///
/// The app knows the timetable, not the person — this is where you *should*
/// be, which is the most any planner can say. It is a value over an injected
/// clock rather than a call to `DateTime.now()` inside a widget, so a test can
/// put the traveller anywhere on the line.
class JourneyProgress {
  const JourneyProgress(this.now);

  /// No clock at all, so nothing is ever behind you.
  ///
  /// The default for callers with none to offer — the search screen's spine
  /// has no times to reason about — so that not knowing draws the line whole
  /// rather than pretending the traveller is somewhere.
  static const JourneyProgress never = JourneyProgress(null);

  final DateTime? now;

  /// How much of the stretch from [from] to [to] is behind, as 0..1.
  ///
  /// Zero when either end is unknown: an unmeasurable stretch is drawn whole
  /// rather than guessed at, because a spine that faded on missing data would
  /// claim the traveller had got further than anyone knows.
  double fractionBetween(DateTime? from, DateTime? to) {
    final now = this.now;
    if (now == null || from == null || to == null) return 0;
    if (!now.isAfter(from)) return 0;
    // A stretch that takes no time is either behind you or ahead of you;
    // there is no part-way through it to draw.
    if (!to.isAfter(from)) return 1;
    if (!now.isBefore(to)) return 1;
    return now.difference(from).inMilliseconds /
        to.difference(from).inMilliseconds;
  }

  /// Whether a moment on the journey is behind the traveller.
  bool hasPassed(DateTime? moment) {
    final now = this.now;
    return now != null && moment != null && !now.isBefore(moment);
  }
}
