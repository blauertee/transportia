import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Names for the text recipes the app writes out most often.
///
/// These were not designed as a scale — they were arrived at one screen at a
/// time, and they sit at eight points in a continuous space of size and alpha.
/// So this is deliberately *not* a full type system: only the recipes that
/// turned out to mean one thing wherever they appear are named here, and a
/// piece of text whose role does not match one of these keeps its own style.
/// A name that had to be stretched to cover its call sites would be worse than
/// the literal it replaced.
///
/// Getters rather than constants: they read [AppColors.black], which follows
/// the theme.
abstract final class AppText {
  /// A section heading, and the title of a card or overlay.
  static TextStyle get heading => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.black,
  );

  /// The title line of a row in a list.
  static TextStyle get listTitle => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.black,
  );

  /// The line you are meant to read first inside a row or a card: a duration,
  /// a price, a headsign, a departure time.
  static TextStyle get bodyStrong => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.black,
  );

  /// Body text that explains rather than states — a paragraph, a hint, an
  /// empty-list note.
  static TextStyle get bodyMuted =>
      TextStyle(fontSize: 14, color: AppColors.black.withValues(alpha: 0.5));

  /// Quieter than [bodyMuted]: the description under a section title, and
  /// placeholder text for a screen with nothing to show yet.
  static TextStyle get bodyFaint =>
      TextStyle(fontSize: 14, color: AppColors.black.withValues(alpha: 0.4));

  /// The subtitle under a title.
  static TextStyle get subtitle => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.black.withValues(alpha: 0.4),
  );

  /// Small print appended under a row's main content.
  static TextStyle get footnote =>
      TextStyle(fontSize: 13, color: AppColors.black.withValues(alpha: 0.5));

  /// The small label naming a value beside or above it.
  static TextStyle get caption =>
      TextStyle(fontSize: 12, color: AppColors.black.withValues(alpha: 0.5));
}
