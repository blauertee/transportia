import 'package:flutter/widgets.dart';

import '../models/itinerary.dart';
import 'color_utils.dart';

/// What a street leg is drawn in.
///
/// A walk or a ride on your own bike belongs to no line, so it borrows no
/// line's colour. Fixed rather than themed: it has to read as "not a service"
/// against both backgrounds, and a slate at this lightness clears 3:1 on
/// white and on the app's near-black alike.
const Color kStreetLegColor = Color(0xFF8A9299);

/// Contrast ratio between two opaque colours, per WCAG.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Pushes [color] away from [background] until it clears [minRatio].
///
/// Hue and saturation are kept, so the line still reads as the operator's —
/// only lightness moves. Feeds ship pale yellows that vanish on white and
/// near-blacks that vanish on the dark theme, and a 2px line has less room to
/// survive that than a block of colour does. 3:1 is the WCAG threshold for
/// non-text graphics, which is what this is.
///
/// Returns [color] untouched when it already passes.
Color ensureContrast(Color color, Color background, {double minRatio = 3.0}) {
  if (contrastRatio(color, background) >= minRatio) return color;

  // On a light background darken, on a dark one lighten — moving the other
  // way would have to cross the background to find contrast on the far side.
  final darken = background.computeLuminance() > 0.5;
  final hsl = HSLColor.fromColor(color);

  // 2% steps: fine enough that the result still looks like the feed's colour,
  // coarse enough to settle in a few dozen iterations.
  for (var i = 1; i <= 50; i++) {
    final lightness =
        (darken ? hsl.lightness - i * 0.02 : hsl.lightness + i * 0.02).clamp(
          0.0,
          1.0,
        );
    final candidate = hsl.withLightness(lightness).toColor();
    if (contrastRatio(candidate, background) >= minRatio) return candidate;
    if (lightness == 0.0 || lightness == 1.0) break;
  }

  // Saturated hues can run out of lightness before they clear the bar — a
  // mid-blue on black, say. Black or white always clears it.
  return darken ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
}

/// The colour of one leg's stretch of the spine.
///
/// The line changes colour exactly where the mode changes, which is what makes
/// the ring read as a junction rather than as decoration sitting on a line.
Color legSpineColor({
  required Leg leg,
  required Color background,
  required Color accent,
  bool isTransfer = false,
}) {
  // A change between two services is not itself a service.
  if (isTransfer || isStreetLeg(leg.mode)) return kStreetLegColor;
  final routeColor = parseHexColor(leg.routeColor);
  if (routeColor == null) return accent;
  return ensureContrast(routeColor, background);
}

/// Modes the traveller covers under their own power or in their own vehicle.
///
/// These get a dotted, neutral stretch: no timetable, no line, no colour.
bool isStreetLeg(String mode) => const {
  'WALK',
  'BIKE',
  'CAR',
  'CAR_PARKING',
  'CAR_DROPOFF',
  'RENTAL',
  'ODM',
}.contains(mode);
