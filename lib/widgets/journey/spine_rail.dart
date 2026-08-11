import 'package:flutter/widgets.dart';

import '../../theme/journey_metrics.dart';
import '../../utils/journey_progress.dart';

/// One row's stretch of the journey line.
///
/// Each row paints its own full-height piece rather than the screen painting
/// one long line: adjacent rows then touch and read as a single unbroken
/// spine, which is what lets the itinerary keep its `SliverList` — a leg is
/// still one child, and the line still crosses between children.
///
/// A leg owns the line from **its own node down to the next one**, so a row
/// that carries a node insets the top by the node's diameter and the colour
/// changes exactly at the ring. Painting from the row's top instead would put
/// the new leg's colour above the node that introduces it.
class SpineRail extends StatelessWidget {
  const SpineRail({
    super.key,
    required this.color,
    this.dashed = false,
    this.topInset = 0,
    this.bottomInset = 0,
    this.travelled = 0,
  });

  final Color color;

  /// Street legs are dashed: you are not on rails, and the line should not
  /// pretend you are.
  final bool dashed;

  /// Where the line starts and stops within this row, measured from each edge.
  final double topInset;
  final double bottomInset;

  /// How much of this stretch is behind the traveller, 0..1.
  ///
  /// Split within the stretch rather than row by row, because a row can be a
  /// four-hour ride: flipping the whole thing at its far end would leave the
  /// indicator motionless for the entire journey it is meant to describe.
  /// Zero by default, so a spine with no times — the search screen's — draws
  /// exactly as it did.
  final double travelled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RailPainter(
        color: color,
        dashed: dashed,
        topInset: topInset,
        bottomInset: bottomInset,
        travelled: travelled.clamp(0.0, 1.0),
      ),
      size: Size.infinite,
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.color,
    required this.dashed,
    required this.topInset,
    required this.bottomInset,
    required this.travelled,
  });

  final Color color;
  final bool dashed;
  final double topInset;
  final double bottomInset;
  final double travelled;

  @override
  void paint(Canvas canvas, Size size) {
    final top = topInset;
    final bottom = size.height - bottomInset;
    if (bottom <= top) return;

    Paint pen(bool behind) => Paint()
      ..color = behind
          ? color.withValues(alpha: color.a * kTravelledOpacity)
          : color
      ..strokeWidth = JourneyMetrics.stroke
      // Round, because Lucide's own strokes are round-capped and a flat line
      // beside a round glyph reads as a different pen.
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final x = size.width / 2;
    // Where the traveller is within this stretch. Everything above it has
    // been ridden.
    final split = top + (bottom - top) * travelled;

    if (!dashed) {
      if (split > top) {
        canvas.drawLine(Offset(x, top), Offset(x, split), pen(true));
      }
      if (split < bottom) {
        canvas.drawLine(Offset(x, split), Offset(x, bottom), pen(false));
      }
      return;
    }

    const step = JourneyMetrics.dash + JourneyMetrics.dashGap;
    // Inset by half the stroke at each end so the round caps of the first and
    // last dash stay inside the stretch this row owns.
    final half = JourneyMetrics.stroke / 2;
    for (var y = top + half; y < bottom - half; y += step) {
      final end = (y + JourneyMetrics.dash).clamp(top + half, bottom - half);
      // A dash is one mark: it takes the side its middle falls on rather than
      // being cut in two, which at this size would read as a printing fault.
      canvas.drawLine(Offset(x, y), Offset(x, end), pen((y + end) / 2 < split));
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.color != color ||
      old.dashed != dashed ||
      old.topInset != topInset ||
      old.bottomInset != bottomInset ||
      old.travelled != travelled;
}
