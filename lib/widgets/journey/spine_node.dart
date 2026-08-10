import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/journey_metrics.dart';

/// The ring on the line that carries a mode glyph.
///
/// It replaces the dot that would otherwise start a segment: the node *is*
/// what you board there, and the line grows out of its underside in that
/// service's colour. Where a plain dot says "a stop happens here", this says
/// which stop and what you do at it.
class SpineNode extends StatelessWidget {
  const SpineNode({
    super.key,
    required this.icon,
    required this.color,
    this.filled = false,
    this.semanticLabel,
  });

  final IconData icon;
  final Color color;

  /// Filled for a terminus, where the ring is the end of the line rather than
  /// a junction on it.
  final bool filled;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final node = Container(
      width: JourneyMetrics.ring,
      height: JourneyMetrics.ring,
      decoration: BoxDecoration(
        // Opaque, so the rail passing behind is hidden rather than showing
        // through the glyph.
        color: filled ? color : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: JourneyMetrics.stroke),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: JourneyMetrics.iconSize * 0.72,
        color: filled ? AppColors.white : color,
      ),
    );

    final label = semanticLabel;
    if (label == null) return node;
    return Semantics(label: label, child: node);
  }
}

/// A stop the service passes through without you doing anything.
///
/// Small and plain on purpose: it marks a place on a line you are already on,
/// so it must not compete with the rings, which mark places you act at.
class SpineDot extends StatelessWidget {
  const SpineDot({super.key, required this.color, this.filled = false});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: JourneyMetrics.minorDot,
      height: JourneyMetrics.minorDot,
      decoration: BoxDecoration(
        color: filled ? color : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: JourneyMetrics.stroke),
      ),
    );
  }
}
