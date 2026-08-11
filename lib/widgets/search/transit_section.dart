import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/routing_options.dart';
import '../../models/transit_mode_group.dart';
import '../../models/transitous/enums.dart';
import '../../theme/app_colors.dart';
import '../options/icon_controls.dart';
import '../options/selectable_tick.dart';

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

  static const int _maxChips = 4;

  List<TransitMode> get _chippedModes =>
      _selection.uncoveredModes.take(_maxChips).toList();

  int get _hiddenChipCount =>
      _selection.uncoveredModes.length - _chippedModes.length;

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
  /// every selected mode the icons cannot be showing — so the row always
  /// carries the whole selection rather than hiding part of it behind a
  /// dropdown.
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
              selected: _selection.stateOf(group) == GroupState.all,
              // Half-lit: some of this group is on, and the chips beside the
              // icons name which.
              subdued: _selection.stateOf(group) == GroupState.some,
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
        // Capped: a deliberately narrow selection can name a dozen modes, and
        // a row of a dozen chips stops being a summary.
        for (final mode in _chippedModes)
          ModeChip(
            label: TransitModeGroup.modeLabel(mode),
            onRemove: () => onChanged(
              options.withTransitSelection(_selection.toggleMode(mode)),
            ),
          ),
        if (_hiddenChipCount > 0)
          ModeChip(label: '+$_hiddenChipCount', onRemove: onModesPressed),
      ],
    );
  }

  /// Every mode the server can route, under the group it belongs to.
  ///
  /// The reference web client lists them flat; twenty unheaded ticks are hard
  /// to scan, and the headings also say which icon above covers what.
  Widget _buildModeList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in TransitModeGroup.values) ...[
          _listHeading(group.label),
          const SizedBox(height: 6),
          _tickWrap(group.modes),
          const SizedBox(height: 10),
        ],
        _listHeading('Other'),
        const SizedBox(height: 6),
        _tickWrap(TransitModeGroup.extras),
      ],
    );
  }

  Widget _listHeading(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
      color: AppColors.black.withValues(alpha: 0.45),
    ),
  );

  Widget _tickWrap(List<TransitMode> modes) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final mode in modes)
        SelectableTick(
          label: TransitModeGroup.modeLabel(mode),
          selected: _selection.has(mode),
          onPressed: () => onChanged(
            options.withTransitSelection(_selection.toggleMode(mode)),
          ),
        ),
    ],
  );

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
        // Always offered, and already on when the same vehicle is at both
        // ends — that is when it is travelling with you rather than being
        // left at the station. The derivation is a starting point, not a
        // gate: turning it off there, or on elsewhere, is a real request.
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
        SliderScaleLabels(
          labels: ['0', '${RoutingOptions.maxTransferChoice}', 'Unlimited'],
        ),
      ],
    );
  }
}

