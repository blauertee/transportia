import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../utils/haptics.dart';

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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The rail piece. Full accent while open, so the line itself says
          // which stage you are editing.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 3,
              decoration: BoxDecoration(
                color: isOpen ? accent : accent.withValues(alpha: 0.26),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
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
      ),
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
