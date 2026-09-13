import 'package:flutter/widgets.dart';

/// Side of the square every timeline indicator is drawn in.
///
/// Anything placed inside one — a vehicle badge, a dot — has to be sized
/// against this, so it is shared rather than repeated.
const double kTimelineIndicatorSize = 28;

/// Width of the connector line running through the box.
const double _kIndicatorLineWidth = 2.5;

class TimelineIndicatorBox extends StatelessWidget {
  const TimelineIndicatorBox({
    super.key,
    required this.child,
    required this.lineColor,
    this.centerGap = 0.0,
    this.cutTop = false,
    this.cutBottom = false,
  });

  final Widget child;
  final Color lineColor;
  final double centerGap;
  final bool cutTop;
  final bool cutBottom;

  @override
  Widget build(BuildContext context) {
    final double gap = centerGap.clamp(0.0, kTimelineIndicatorSize);
    final double sideLen = (kTimelineIndicatorSize - gap) / 2.0;

    return SizedBox(
      width: kTimelineIndicatorSize,
      height: kTimelineIndicatorSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!cutTop && sideLen > 0)
            Positioned(
              top: 0,
              child: SizedBox(
                width: _kIndicatorLineWidth,
                height: sideLen,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: lineColor),
                ),
              ),
            ),
          if (!cutBottom && sideLen > 0)
            Positioned(
              bottom: 0,
              child: SizedBox(
                width: _kIndicatorLineWidth,
                height: sideLen,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: lineColor),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
