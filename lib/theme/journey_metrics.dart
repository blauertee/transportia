/// The geometry of the journey spine, derived from the icon set rather than
/// guessed at.
///
/// Lucide ships its glyphs on a 24-unit grid with a stroke of 2, and
/// `lucide_icons_flutter` builds its font from exactly those SVGs — measuring
/// the `minus` glyph in the shipped `lucide.ttf` (a single horizontal rule, so
/// its height *is* the stroke) gives 1.97 units on that grid. An icon rendered
/// at [iconSize] therefore paints a stroke of `iconSize * 0.0820`.
///
/// Every line, ring and dot on the spine uses that same number. Without it the
/// icons sit *on top of* a chart drawn in some other weight; with it the whole
/// thing reads as one drawing.
abstract final class JourneyMetrics {
  /// The size every mode glyph is rendered at.
  static const double iconSize = 24;

  /// What a [iconSize] glyph actually paints: 24 * 0.0820 = 1.97.
  static const double stroke = 2;

  /// Diameter of the ring that carries a mode glyph.
  ///
  /// Enough room for the glyph plus the ring's own stroke and a little air, so
  /// the two do not touch.
  static const double ring = 38;

  /// The dot for a stop the service only passes through.
  static const double minorDot = 11;

  /// The gutter the rail and its nodes live in. Same as [ring], so a node is
  /// centred on the rail by construction.
  static const double gutter = ring;

  /// Right-aligned column of times, left of the rail.
  static const double timeColumn = 52;

  /// Between the rail's gutter and the text that belongs to it.
  static const double gap = 12;

  /// The inset every row keeps from the screen edge. Anything laid out beside
  /// the spine uses it too, so a map icon in a leg and one in the journey
  /// header land on the same edge.
  static const double screenPadding = 16;

  /// A dashed rail: [dash] painted, [dashGap] skipped, repeating.
  static const double dash = 4;
  static const double dashGap = 5;
}
