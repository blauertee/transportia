import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../buttons/pill_button.dart';
import '../pressable_highlight.dart';

/// How long the modal takes to scale and fade in, and back out again.
const Duration _kModalTransitionDuration = Duration(milliseconds: 280);

/// The dimmed map behind the card.
const Color _kModalBarrierColor = Color(0xBF000000);

/// Gutter kept between the card and the screen edges, whatever [maxCardWidth]
/// asks for.
const double _kMinScreenGutter = 48.0;

/// Side of the square holding the card's leading icon.
const double _kHeaderIconBoxSize = 40.0;

/// A card floating over the map, scaled and faded in over a dimmed backdrop.
///
/// The map owns the modal's lifetime rather than the navigator, so closing is
/// two steps: the owner sets [isClosing], and [onClosed] fires once the exit
/// animation has actually finished and the widget can be torn down.
class MapSelectionModal extends StatefulWidget {
  const MapSelectionModal({
    super.key,
    required this.identity,
    required this.onDismissRequested,
    required this.onClosed,
    required this.isClosing,
    required this.child,
    this.horizontalPadding = 32,
    this.maxCardWidth = 340,
    this.cardPadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
    this.entryScale = 1.1,
  });

  /// What the card is about. When it changes the modal replays its entrance,
  /// so tapping a second stop reads as a new card rather than a silent swap.
  final Object? identity;

  final VoidCallback onDismissRequested;

  /// Called once the exit animation has finished, or immediately if the modal
  /// was never shown.
  final VoidCallback onClosed;

  final bool isClosing;
  final Widget child;
  final double horizontalPadding;
  final double maxCardWidth;
  final EdgeInsetsGeometry cardPadding;
  final double entryScale;

  @override
  State<MapSelectionModal> createState() => _MapSelectionModalState();
}

class _MapSelectionModalState extends State<MapSelectionModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;
  late final Animation<double> _backdropOpacity;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: _kModalTransitionDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.dismissed) widget.onClosed();
          });
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.linearToEaseOut,
      reverseCurve: Curves.easeInToLinear,
    );
    _scale = Tween<double>(begin: widget.entryScale, end: 1.0).animate(_curve);
    _backdropOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_curve);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant MapSelectionModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isClosing && widget.isClosing) {
      _startClosing();
    } else if (oldWidget.identity != widget.identity && !widget.isClosing) {
      _controller.forward(from: 0.0);
    }
  }

  void _startClosing() {
    if (_controller.value == 0.0) {
      widget.onClosed();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = math.min(
      screenWidth - _kMinScreenGutter,
      widget.maxCardWidth,
    );

    return FadeTransition(
      opacity: _backdropOpacity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismissRequested,
        child: Container(
          color: _kModalBarrierColor,
          alignment: Alignment.center,
          child: GestureDetector(
            // Swallows taps on the card so they do not dismiss it.
            onTap: () {},
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalPadding,
              ),
              child: ScaleTransition(
                scale: _scale,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 36,
                          offset: Offset(0, 24),
                        ),
                      ],
                    ),
                    padding: widget.cardPadding,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The icon, title and subtitle a map modal opens with.
class MapModalHeader extends StatelessWidget {
  const MapModalHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.clipText = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Set for text that can run long, such as a stop name.
  final bool clipText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: _kHeaderIconBoxSize,
          height: _kHeaderIconBoxSize,
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.black.withValues(alpha: 0.07)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.black),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: _kHeaderIconBoxSize,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLine(title, fontSize: 17, weight: FontWeight.w700),
                _buildLine(
                  subtitle,
                  fontSize: 13,
                  weight: FontWeight.w500,
                  alpha: 0.6,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLine(
    String text, {
    required double fontSize,
    required FontWeight weight,
    double alpha = 1.0,
  }) => Text(
    text,
    maxLines: clipText ? 1 : null,
    overflow: clipText ? TextOverflow.ellipsis : null,
    style: TextStyle(
      fontWeight: weight,
      fontSize: fontSize,
      color: alpha == 1.0
          ? AppColors.black
          : AppColors.black.withValues(alpha: alpha),
    ),
  );
}

/// The paired Origin / Destination buttons a map modal offers a place through.
class OriginDestinationPicker extends StatelessWidget {
  const OriginDestinationPicker({
    super.key,
    required this.onSelectFrom,
    required this.onSelectTo,
  });

  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.black.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _segment(
            label: 'Origin',
            icon: LucideIcons.arrowUpFromDot,
            onTap: onSelectFrom,
            radius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            alignEnd: false,
          ),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: const Color(0x33000000),
          ),
          _segment(
            label: 'Destination',
            icon: LucideIcons.arrowDownToDot,
            onTap: onSelectTo,
            radius: const BorderRadius.only(
              topRight: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            alignEnd: true,
          ),
        ],
      ),
    );
  }

  /// One half of the picker. The two mirror each other so the icons sit at the
  /// outer edges and the labels meet in the middle.
  Widget _segment({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required BorderRadius radius,
    required bool alignEnd,
  }) {
    final iconWidget = Icon(icon, size: 18, color: AppColors.black);
    final labelWidget = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 15,
        color: AppColors.black,
      ),
    );

    return Expanded(
      child: PillButton(
        onTap: onTap,
        borderRadius: radius,
        restingColor: const Color(0x00000000),
        pressedColor: const Color(0x00000000),
        borderColor: const Color(0x00000000),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: FittedBox(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: alignEnd
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: alignEnd
                ? [labelWidget, const SizedBox(width: 8), iconWidget]
                : [iconWidget, const SizedBox(width: 8), labelWidget],
          ),
        ),
      ),
    );
  }
}

/// A centred icon-and-label action, as the modals use for Dismiss and for
/// opening the full timetable.
class MapModalTextAction extends StatelessWidget {
  const MapModalTextAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.fontWeight = FontWeight.w500,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Align(
      alignment: Alignment.center,
      child: PressableHighlight(
        onPressed: onPressed,
        highlightColor: accent,
        borderRadius: BorderRadius.circular(14),
        enableHaptics: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontWeight: fontWeight,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
