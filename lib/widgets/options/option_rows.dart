import 'package:flutter/widgets.dart';

import '../../models/transitous/enums.dart';
import '../search/street_leg_section.dart';
import '../../theme/app_colors.dart';
import '../app_toggle_switch.dart';
import 'value_controls.dart';

/// A labelled switch row, matching the settings rows used elsewhere.
class OptionToggleRow extends StatelessWidget {
  const OptionToggleRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(fontSize: 15, color: AppColors.black),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.black.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppToggleSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
        if (!isLast)
          Container(height: 1, color: AppColors.black.withValues(alpha: 0.06)),
      ],
    );
  }
}

/// Picks the street modes a leg may use.
///
/// Several at once, because the server takes a list and "walk or grab a bike"
/// is how people actually get to a stop. Never empty — the caller falls back
/// to walking rather than sending a leg that can route nothing.
class ModeChoiceRow extends StatelessWidget {
  const ModeChoiceRow({
    super.key,
    required this.modes,
    required this.selected,
    required this.onChanged,
  });

  final List<TransitMode> modes;
  final List<TransitMode> selected;
  final ValueChanged<List<TransitMode>> onChanged;

  void _toggle(TransitMode mode) => onChanged([
    for (final candidate in modes)
      if (candidate == mode
          ? !selected.contains(mode)
          : selected.contains(candidate))
        candidate,
  ]);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final width = (constraints.maxWidth - spacing * 2) / 3;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final mode in modes)
              SizedBox(
                width: width,
                child: QuickValueCard(
                  value: mileModeLabel(mode),
                  selected: selected.contains(mode),
                  onTap: () => _toggle(mode),
                ),
              ),
          ],
        );
      },
    );
  }
}
