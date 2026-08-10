import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/journey_metrics.dart';
import '../../utils/haptics.dart';
import '../journey/spine_node.dart';
import '../journey/spine_row.dart';

/// The first line of a stage's text, stated so [SpineRow] can centre it.
const double kStageLineHeight = 16;

/// One stage of the journey being planned, as a node on the same spine the
/// itinerary is drawn with.
///
/// The three stages used to be separated by the rail *breaking* between them,
/// which made the search read as a settings list that happened to have a line
/// beside it. Unbroken, with the stage's own mode in a ring and street stages
/// dotted, it reads as the shape of the trip you are asking for — which is
/// what laying the options out in journey order was for.
class JourneySegment extends StatelessWidget {
  const JourneySegment({
    super.key,
    required this.icon,
    required this.headline,
    required this.summary,
    required this.isOpen,
    required this.onToggle,
    required this.child,
    required this.color,
    this.dashed = false,
  });

  /// Reflects the current choice, e.g. a bike once a bike is picked.
  final IconData icon;

  /// Names the stage: "To the station", "Public transport".
  final String headline;

  /// The current state in one line, readable without expanding.
  final String summary;

  final bool isOpen;
  final VoidCallback onToggle;

  /// Controls shown once the stage is expanded.
  final Widget child;

  /// The stage's stretch of the line.
  final Color color;

  /// Street stages are dotted: you are not on rails.
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return SpineRow(
      timeColumn: 0,
      padding: EdgeInsets.zero,
      node: SpineNode(icon: icon, color: color, semanticLabel: headline),
      railColor: color,
      railDashed: dashed,
      railTopInset: JourneyMetrics.ring,
      firstLineHeight: kStageLineHeight,
      meta: AnimatedRotation(
        turns: isOpen ? 0.25 : 0,
        duration: const Duration(milliseconds: 180),
        child: Icon(
          LucideIcons.chevronRight,
          size: 14,
          color: AppColors.black.withValues(alpha: 0.45),
        ),
      ),
      body: Semantics(
        button: true,
        expanded: isOpen,
        label: '$headline. $summary',
        child: Padding(
          // The gap between stages lives inside the row, so the rails of
          // adjacent stages touch and the line stays unbroken.
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Haptics.lightTick();
                  onToggle();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: kStageLineHeight / 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: AppColors.black),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: isOpen
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
