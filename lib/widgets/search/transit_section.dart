import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/routing_options.dart';
import '../../models/transit_mode_group.dart';
import '../../theme/app_colors.dart';
import '../options/icon_controls.dart';

/// The icon each transport group shows.
const Map<TransitModeGroup, IconData> transitGroupIcons = {
  TransitModeGroup.rail: LucideIcons.trainFront,
  TransitModeGroup.metro: LucideIcons.trainFrontTunnel,
  TransitModeGroup.bus: LucideIcons.bus,
  TransitModeGroup.boat: LucideIcons.ship,
};

/// Which transport to use, how many changes to accept, and the qualifiers
/// that belong to the vehicle rather than to a street leg.
class TransitSection extends StatelessWidget {
  const TransitSection({
    super.key,
    required this.options,
    required this.tooltips,
    required this.modesOpen,
    required this.changesOpen,
    required this.onChanged,
    required this.onModesPressed,
    required this.onChangesPressed,
    required this.onViaPressed,
  });

  final RoutingOptions options;
  final OptionTooltipController tooltips;

  /// The full mode list, open on request.
  final bool modesOpen;

  /// The transfer-limit slider, open on request.
  final bool changesOpen;

  final ValueChanged<RoutingOptions> onChanged;
  final VoidCallback onModesPressed;
  final VoidCallback onChangesPressed;
  final VoidCallback onViaPressed;

  TransitSelection get _selection => options.transitSelection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModeCloud(context),
        if (modesOpen) ...[const SizedBox(height: 10), _buildModeList(context)],
        const SizedBox(height: 8),
        _buildMetaRow(context),
        if (changesOpen) ...[
          const SizedBox(height: 4),
          _buildChangesSlider(context),
        ],
      ],
    );
  }

  /// Four group icons, the button that opens the rest, and a named chip for
  /// anything picked from it — so the row always carries the whole selection
  /// rather than hiding part of it behind a dropdown.
  Widget _buildModeCloud(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final group in TransitModeGroup.values)
          SizedBox(
            width: 42,
            child: IconPick(
              icon: transitGroupIcons[group]!,
              label: group.label,
              selected: _selection.has(group),
              tooltips: tooltips,
              onPressed: () => onChanged(
                options.withTransitSelection(_selection.toggleGroup(group)),
              ),
            ),
          ),
        SizedBox(
          width: 42,
          child: IconPick(
            icon: modesOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            label: 'More transport',
            selected: false,
            subdued: true,
            size: 16,
            tooltips: tooltips,
            onPressed: onModesPressed,
          ),
        ),
        for (final mode in TransitModeGroup.extras)
          if (_selection.extras.contains(mode))
            ModeChip(
              label: TransitModeGroup.extraLabel(mode),
              onRemove: () => onChanged(
                options.withTransitSelection(_selection.toggleExtra(mode)),
              ),
            ),
      ],
    );
  }

  Widget _buildModeList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EVERYTHING THIS SERVICE CAN ROUTE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.black.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final mode in TransitModeGroup.extras)
              _ModeTick(
                label: TransitModeGroup.extraLabel(mode),
                selected: _selection.extras.contains(mode),
                onPressed: () => onChanged(
                  options.withTransitSelection(_selection.toggleExtra(mode)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Transfer limit, carriage, reservation and via — the qualifiers that
  /// belong to the vehicle rather than to either street leg.
  Widget _buildMetaRow(BuildContext context) {
    final unlimited = options.maxTransfers == null;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ValueChip(
          icon: LucideIcons.waypoints,
          label: 'Maximum changes',
          value: unlimited ? null : '${options.maxTransfers}',
          valueIcon: unlimited ? LucideIcons.infinity : null,
          tooltips: tooltips,
          expanded: changesOpen,
          onPressed: onChangesPressed,
        ),
        // Only offered once a bike is at both ends, because that is when
        // carriage can matter. Still the rider's to turn off from there.
        if (options.bikeAtBothEnds)
          SizedBox(
            width: 42,
            child: IconPick(
              icon: LucideIcons.bike,
              label: options.requireBikeTransport
                  ? 'Bike carried on board'
                  : 'Bike not carried',
              selected: options.requireBikeTransport,
              tooltips: tooltips,
              onPressed: () => onChanged(
                options.copyWith(
                  bikeCarriageOverride: !options.requireBikeTransport,
                ),
              ),
            ),
          ),
        if (options.carAtBothEnds)
          SizedBox(
            width: 42,
            child: IconPick(
              icon: LucideIcons.car,
              label: options.requireCarTransport
                  ? 'Car carried on board'
                  : 'Car not carried',
              selected: options.requireCarTransport,
              tooltips: tooltips,
              onPressed: () => onChanged(
                options.copyWith(
                  carCarriageOverride: !options.requireCarTransport,
                ),
              ),
            ),
          ),
        SizedBox(
          width: 42,
          child: IconPick(
            icon: LucideIcons.ticketX,
            label: 'No reservation needed',
            selected: options.noCompulsoryReservation,
            tooltips: tooltips,
            onPressed: () => onChanged(
              options.copyWith(
                noCompulsoryReservation: !options.noCompulsoryReservation,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 42,
          child: IconPick(
            icon: LucideIcons.mapPin,
            label: options.via.isEmpty
                ? 'Travel through a stop'
                : 'Travelling through ${options.via.length} '
                      '${options.via.length == 1 ? "stop" : "stops"}',
            selected: options.via.isNotEmpty,
            tooltips: tooltips,
            onPressed: onViaPressed,
          ),
        ),
      ],
    );
  }

  Widget _buildChangesSlider(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionSlider(
          value: options.transfersSliderValue.toDouble(),
          max: RoutingOptions.unlimitedTransfersSliderValue.toDouble(),
          divisions: RoutingOptions.unlimitedTransfersSliderValue,
          semanticLabel: 'Maximum changes',
          onChanged: (value) =>
              onChanged(options.withTransfersSliderValue(value.round())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _scaleLabel('0'),
              _scaleLabel('${RoutingOptions.maxTransferChoice}'),
              _scaleLabel('Unlimited'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scaleLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 10.5,
      color: AppColors.black.withValues(alpha: 0.45),
    ),
  );
}

class _ModeTick extends StatelessWidget {
  const _ModeTick({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

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
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.13)
                : const Color(0x00000000),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? accent
                  : AppColors.black.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? accent : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}
