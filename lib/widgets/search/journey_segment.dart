import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../utils/haptics.dart';

/// The rail itself.
const double journeyRailWidth = 3;

/// The gutter the rail shares with the origin and destination dots, so the
/// line reads as one route from the first marker to the last.
const double journeyGutterWidth = journeyRailWidth + 17;

/// One stage of the journey, with its own stretch of the rail on the left.
///
/// The three stages are separated by the rail breaking between them, by the
/// spacing around them and by the headline, rather than by a box each. Boxes
/// inside a card that is itself a box read as clutter, and the rail carries
/// the sequence — which is the point of laying the options out this way.
class JourneySegment extends StatelessWidget {
  const JourneySegment({
    super.key,
    required this.icon,
    required this.headline,
    required this.summary,
    required this.isOpen,
    required this.onToggle,
    required this.child,
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

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);

    // The rail is stacked behind the content rather than laid beside it in a
    // stretched Row: that would need an IntrinsicHeight, and the height of an
    // expanding section is mid-animation exactly when it is asked for.
    return Stack(
      children: [
        // Full accent while open, so the line itself says which stage you
        // are editing.
        Positioned(
          left: 0,
          top: 3,
          bottom: 3,
          width: journeyRailWidth,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: isOpen ? accent : accent.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: journeyGutterWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SegmentHeader(
                icon: icon,
                headline: headline,
                summary: summary,
                isOpen: isOpen,
                onToggle: onToggle,
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
      ],
    );
  }
}

class _SegmentHeader extends StatelessWidget {
  const _SegmentHeader({
    required this.icon,
    required this.headline,
    required this.summary,
    required this.isOpen,
    required this.onToggle,
  });

  final IconData icon;
  final String headline;
  final String summary;
  final bool isOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);

    return Semantics(
      button: true,
      expanded: isOpen,
      label: '$headline. $summary',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.lightTick();
          onToggle();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: accent,
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
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isOpen ? 0.25 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  LucideIcons.chevronRight,
                  size: 14,
                  color: AppColors.black.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
