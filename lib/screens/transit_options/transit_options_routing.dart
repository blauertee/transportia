import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/routing_options.dart';
import '../../models/transitous/enums.dart';
import '../../models/transitous/server_config.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/section_title.dart';
import '../../widgets/options/option_rows.dart';
import '../../widgets/options/value_controls.dart';

/// Toggles for the journey requirements: routed transfers, step-free paths,
/// bike and car carriage, and reservation-free services.
class TransitOptionsRequirementsCard extends StatelessWidget {
  const TransitOptionsRequirementsCard({
    super.key,
    required this.options,
    required this.capabilities,
    required this.onChanged,
  });

  final RoutingOptions options;
  final ServerConfig capabilities;
  final ValueChanged<RoutingOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Requirements'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              // A server without street routing cannot route transfers, so
              // offering the switch would be misleading.
              if (capabilities.hasRoutedTransfers)
                OptionToggleRow(
                  icon: LucideIcons.footprints,
                  label: 'Use routed transfers',
                  description:
                      'Walk transfers along real paths instead of the '
                      'timetable’s fixed times.',
                  value: options.useRoutedTransfers,
                  onChanged: (value) =>
                      onChanged(options.copyWith(useRoutedTransfers: value)),
                ),
              OptionToggleRow(
                icon: LucideIcons.accessibility,
                label: 'Step-free connections only',
                description: 'Avoid stairs and unmarked kerbs on foot legs.',
                value: options.wheelchairAccessibleOnly,
                onChanged: (value) => onChanged(
                  options.copyWith(wheelchairAccessibleOnly: value),
                ),
              ),
              OptionToggleRow(
                icon: LucideIcons.bike,
                label: 'Bike carriage',
                description: 'Only services that carry bicycles.',
                value: options.requireBikeTransport,
                onChanged: (value) =>
                    onChanged(options.copyWith(bikeCarriageOverride: value)),
              ),
              OptionToggleRow(
                icon: LucideIcons.car,
                label: 'Car carriage',
                description: 'Only services that carry cars.',
                value: options.requireCarTransport,
                onChanged: (value) =>
                    onChanged(options.copyWith(carCarriageOverride: value)),
              ),
              OptionToggleRow(
                icon: LucideIcons.ticketX,
                label: 'No reservation required',
                description: 'Skip services you must book a seat on.',
                value: options.noCompulsoryReservation,
                onChanged: (value) =>
                    onChanged(options.copyWith(noCompulsoryReservation: value)),
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Maximum number of transfers.
class TransitOptionsTransferLimitCard extends StatelessWidget {
  const TransitOptionsTransferLimitCard({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final RoutingOptions options;
  final ValueChanged<RoutingOptions> onChanged;

  /// Null is "no limit", which is also what the server assumes.
  static const List<int?> _choices = [0, 1, 2, 3, null];

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Maximum transfers'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.shuffle, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    options.maxTransfers == null
                        ? 'No limit'
                        : options.maxTransfers == 0
                        ? 'Direct journeys only'
                        : '${options.maxTransfers} '
                              '${options.maxTransfers == 1 ? "transfer" : "transfers"}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < _choices.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: QuickValueCard(
                        value: _choices[i]?.toString() ?? 'Any',
                        selected: options.maxTransfers == _choices[i],
                        onTap: () => onChanged(
                          options.copyWith(
                            maxTransfers: _choices[i],
                            clearMaxTransfers: _choices[i] == null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// How to get to the first stop, from the last one, and whether to offer a
/// journey with no transit at all.
class TransitOptionsStreetLegsCard extends StatelessWidget {
  const TransitOptionsStreetLegsCard({
    super.key,
    required this.options,
    required this.capabilities,
    required this.onChanged,
  });

  final RoutingOptions options;
  final ServerConfig capabilities;
  final ValueChanged<RoutingOptions> onChanged;

  static const List<int> _budgetChoices = [5, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    // The server clamps anything above its own limits, so offering larger
    // values would just be a lie about what will happen.
    final prePostCap = capabilities.maxPrePostTransitTime;
    final directCap = capabilities.maxDirectTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Getting to and from transit'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StreetLegRow(
                icon: LucideIcons.logIn,
                label: 'First mile',
                modes: options.firstMileModes,
                budget: options.maxFirstMileTime,
                maxBudget: prePostCap,
                budgetChoices: _budgetChoices,
                onModesChanged: (modes) =>
                    onChanged(options.copyWith(firstMileModes: modes)),
                onBudgetChanged: (budget) =>
                    onChanged(options.copyWith(maxFirstMileTime: budget)),
              ),
              const SizedBox(height: 20),
              _StreetLegRow(
                icon: LucideIcons.logOut,
                label: 'Last mile',
                modes: options.lastMileModes,
                budget: options.maxLastMileTime,
                maxBudget: prePostCap,
                budgetChoices: _budgetChoices,
                onModesChanged: (modes) =>
                    onChanged(options.copyWith(lastMileModes: modes)),
                onBudgetChanged: (budget) =>
                    onChanged(options.copyWith(maxLastMileTime: budget)),
              ),
              const SizedBox(height: 20),
              _StreetLegRow(
                icon: LucideIcons.moveRight,
                label: 'Direct journey',
                description:
                    'Offer a route with no transit when it is short enough.',
                modes: options.directModes,
                budget: options.maxDirectTime,
                maxBudget: directCap,
                budgetChoices: _budgetChoices,
                onModesChanged: (modes) =>
                    onChanged(options.copyWith(directModes: modes)),
                onBudgetChanged: (budget) =>
                    onChanged(options.copyWith(maxDirectTime: budget)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreetLegRow extends StatelessWidget {
  const _StreetLegRow({
    required this.icon,
    required this.label,
    required this.modes,
    required this.budget,
    required this.maxBudget,
    required this.budgetChoices,
    required this.onModesChanged,
    required this.onBudgetChanged,
    this.description,
  });

  final IconData icon;
  final String label;
  final String? description;
  final List<TransitMode> modes;
  final Duration budget;
  final Duration maxBudget;
  final List<int> budgetChoices;
  final ValueChanged<List<TransitMode>> onModesChanged;
  final ValueChanged<Duration> onBudgetChanged;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final choices = budgetChoices
        .where((m) => Duration(minutes: m) <= maxBudget)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.black.withValues(alpha: 0.45),
            ),
          ),
        ],
        const SizedBox(height: 10),
        ModeChoiceRow(
          modes: RoutingOptions.streetModeChoices,
          selected: modes,
          onChanged: onModesChanged,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < choices.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: QuickValueCard(
                  value: '${choices[i]} min',
                  selected: budget.inMinutes == choices[i],
                  onTap: () => onBudgetChanged(Duration(minutes: choices[i])),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Cycling speed and incline avoidance.
///
/// Walking speed keeps its own card, since it applies to almost every
/// journey while these two only matter for some.
class TransitOptionsTerrainCard extends StatelessWidget {
  const TransitOptionsTerrainCard({
    super.key,
    required this.options,
    required this.capabilities,
    required this.onChanged,
  });

  final RoutingOptions options;
  final ServerConfig capabilities;
  final ValueChanged<RoutingOptions> onChanged;

  static const List<double> _cyclingPresets = [12.0, 15.1, 20.0, 25.0];

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Cycling'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.bike, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    '${options.cyclingSpeedKmh.toStringAsFixed(1)} km/h',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < _cyclingPresets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: QuickValueCard(
                        value: _cyclingPresets[i].toStringAsFixed(1),
                        selected:
                            (options.cyclingSpeedKmh - _cyclingPresets[i])
                                .abs() <
                            0.05,
                        onTap: () => onChanged(
                          options.copyWith(cyclingSpeedKmh: _cyclingPresets[i]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              StepperSelector(
                value: options.cyclingSpeedKmh,
                minValue: 5.0,
                maxValue: 35.0,
                step: 0.1,
                label: 'km/h',
                displayBuilder: (value) => value.toStringAsFixed(1),
                onChanged: (value) => onChanged(
                  options.copyWith(
                    cyclingSpeedKmh: double.parse(value.toStringAsFixed(1)),
                  ),
                ),
              ),
              // Without elevation data the server ignores this entirely.
              if (capabilities.hasElevation) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(LucideIcons.mountain, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      'Avoid steep inclines',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Trades a longer route for a flatter one.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.black.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final entry in const {
                      ElevationCosts.none: 'No detours',
                      ElevationCosts.low: 'Small detours',
                      ElevationCosts.high: 'Large detours',
                    }.entries) ...[
                      if (entry.key != ElevationCosts.none)
                        const SizedBox(width: 8),
                      Expanded(
                        child: QuickValueCard(
                          value: entry.value,
                          selected: options.elevationCosts == entry.key,
                          onTap: () => onChanged(
                            options.copyWith(elevationCosts: entry.key),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
