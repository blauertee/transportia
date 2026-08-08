import 'package:flutter/widgets.dart';

import '../../models/transitous/enums.dart';
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

/// Picks one street mode from a short row of choices.
class ModeChoiceRow extends StatelessWidget {
  const ModeChoiceRow({
    super.key,
    required this.modes,
    required this.selected,
    required this.onChanged,
  });

  final List<TransitMode> modes;
  final TransitMode selected;
  final ValueChanged<TransitMode> onChanged;

  static const Map<TransitMode, String> _labels = {
    TransitMode.walk: 'Walk',
    TransitMode.bike: 'Bike',
    TransitMode.rental: 'Rental',
    TransitMode.car: 'Car',
    TransitMode.carParking: 'Park',
    TransitMode.carDropoff: 'Drop-off',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < modes.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: QuickValueCard(
              value: _labels[modes[i]] ?? modes[i].wireName,
              selected: selected == modes[i],
              onTap: () => onChanged(modes[i]),
            ),
          ),
        ],
      ],
    );
  }
}
