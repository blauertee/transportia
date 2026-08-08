import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/routing_options.dart';
import '../../models/transitous/enums.dart';
import '../../theme/app_colors.dart';
import '../options/icon_controls.dart';

/// Which street mode a mile can use, and what each is called.
///
/// The labels say what you do rather than naming the enum: nobody asks for
/// `CAR_PARKING`, they park and ride.
const Map<TransitMode, ({IconData icon, String label})> mileModeChoices = {
  TransitMode.walk: (icon: LucideIcons.footprints, label: 'Walk'),
  TransitMode.bike: (icon: LucideIcons.bike, label: 'Bike'),
  TransitMode.rental: (icon: LucideIcons.scooter, label: 'Rental'),
  TransitMode.carParking: (
    icon: LucideIcons.squareParking,
    label: 'Park & ride',
  ),
  TransitMode.carDropoff: (icon: LucideIcons.car, label: 'Drop-off'),
};

IconData mileModeIcon(TransitMode mode) =>
    mileModeChoices[mode]?.icon ?? LucideIcons.footprints;

String mileModeLabel(TransitMode mode) =>
    mileModeChoices[mode]?.label ?? 'Walk';

/// A budget in minutes, compact enough to sit beside a clock icon.
///
/// A raw `120` next to a clock reads as a bug when the line above says two
/// hours, so anything past an hour is shown as hours.
String budgetChipText(Duration budget) {
  final minutes = budget.inMinutes;
  if (minutes < 60) return '$minutes';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h$rest';
}

/// The same budget spelled out for the summary line.
String budgetSummaryText(Duration budget) {
  final minutes = budget.inMinutes;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest';
}

/// Mode picks and a time budget for one of the two street legs.
class StreetLegSection extends StatelessWidget {
  const StreetLegSection({
    super.key,
    required this.mode,
    required this.budget,
    required this.maxBudget,
    required this.tooltips,
    required this.budgetOpen,
    required this.onModeChanged,
    required this.onBudgetChanged,
    required this.onBudgetPressed,
  });

  final TransitMode mode;
  final Duration budget;

  /// The server's own ceiling, so the slider cannot offer what will be
  /// clamped away.
  final Duration maxBudget;

  final OptionTooltipController tooltips;
  final bool budgetOpen;
  final ValueChanged<TransitMode> onModeChanged;
  final ValueChanged<Duration> onBudgetChanged;
  final VoidCallback onBudgetPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final entry in mileModeChoices.entries) ...[
              if (entry.key != mileModeChoices.keys.first)
                const SizedBox(width: 6),
              Expanded(
                child: IconPick(
                  icon: entry.value.icon,
                  label: entry.value.label,
                  selected: mode == entry.key,
                  tooltips: tooltips,
                  onPressed: () => onModeChanged(entry.key),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ValueChip(
            icon: LucideIcons.clock,
            label: 'Time budget',
            value: budgetChipText(budget),
            tooltips: tooltips,
            expanded: budgetOpen,
            onPressed: onBudgetPressed,
          ),
        ),
        if (budgetOpen) ...[
          const SizedBox(height: 4),
          _BudgetSlider(
            budget: budget,
            maxBudget: maxBudget,
            onChanged: onBudgetChanged,
          ),
        ],
      ],
    );
  }
}

class _BudgetSlider extends StatelessWidget {
  const _BudgetSlider({
    required this.budget,
    required this.maxBudget,
    required this.onChanged,
  });

  final Duration budget;
  final Duration maxBudget;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = maxBudget.inMinutes.toDouble();
    final step = RoutingOptions.mileBudgetStep.inMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionSlider(
          value: budget.inMinutes.toDouble().clamp(0, maxMinutes),
          max: maxMinutes,
          divisions: (maxMinutes / step).round(),
          semanticLabel: 'Minutes',
          onChanged: (value) =>
              onChanged(Duration(minutes: (value / step).round() * step)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _scaleLabel(context, '0'),
              _scaleLabel(context, budgetSummaryText(maxBudget ~/ 2)),
              _scaleLabel(context, budgetSummaryText(maxBudget)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scaleLabel(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 10.5,
      color: AppColors.black.withValues(alpha: 0.45),
    ),
  );
}
