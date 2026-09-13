import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';

/// How long a tick takes to take on, or shed, its selected colours.
const Duration _kTickTransition = Duration(milliseconds: 140);

/// A small outlined chip that is either picked or not.
///
/// Used for the options offered as words rather than icons — the less common
/// travel modes, which would bury the four that matter if each got a card.
class SelectableTick extends StatelessWidget {
  const SelectableTick({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  }) : padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
       fontSize = 12,
       unselectedBorderAlpha = 0.12;

  /// The roomier tick used where the chips are the row's main content rather
  /// than a footnote under it.
  const SelectableTick.large({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  }) : padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
       fontSize = 13,
       unselectedBorderAlpha = 0.14;

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double unselectedBorderAlpha;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: _kTickTransition,
          padding: padding,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.13)
                : const Color(0x00000000),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? accent
                  : AppColors.black.withValues(alpha: unselectedBorderAlpha),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: selected ? accent : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}
