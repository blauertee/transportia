import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../environment.dart';
import '../models/routing_options.dart';
import '../models/transitous/enums.dart';
import '../models/transitous/server_config.dart';
import '../providers/theme_provider.dart';
import '../services/routing_options_service.dart';
import '../services/server_capabilities_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/custom_card.dart';
import '../widgets/section_title.dart';
import '../widgets/selectable_icon_card.dart';
import 'transit_options/transit_options_backend.dart';
import 'transit_options/transit_options_routing.dart';
import 'transit_options/transit_options_via_stops.dart';
import 'transit_options/transit_options_widgets.dart';

/// Groups the transit modes into the handful of categories worth toggling.
///
/// A category is on when every mode in it is selected, so the underlying
/// per-mode list stays exact while the UI stays short.
class _ModeGroup {
  const _ModeGroup(this.label, this.modes);

  final String label;
  final List<TransitMode> modes;
}

const List<_ModeGroup> _modeGroups = [
  _ModeGroup('Trains', [
    TransitMode.rail,
    TransitMode.highspeedRail,
    TransitMode.longDistance,
    TransitMode.nightRail,
    TransitMode.regionalFastRail,
    TransitMode.regionalRail,
  ]),
  _ModeGroup('Metro', [TransitMode.metro, TransitMode.subway]),
  _ModeGroup('Tram', [TransitMode.tram, TransitMode.suburban]),
  _ModeGroup('Bus', [TransitMode.bus, TransitMode.coach, TransitMode.odm]),
  _ModeGroup('Walking', [
    TransitMode.walk,
    TransitMode.bike,
    TransitMode.rental,
  ]),
  _ModeGroup('Ferries', [TransitMode.ferry]),
  _ModeGroup('Lifts', [
    TransitMode.cableCar,
    TransitMode.funicular,
    TransitMode.aerialLift,
    TransitMode.arealLift,
  ]),
  _ModeGroup('Flights', [TransitMode.airplane]),
  _ModeGroup('Others', [TransitMode.transit, TransitMode.other]),
];

/// Every mode the categories cover. Selecting all of them means the same as
/// selecting none, so the stored list is emptied in that case.
final Set<TransitMode> _allGroupedModes = {
  for (final group in _modeGroups) ...group.modes,
};

class TransitOptionsScreen extends StatefulWidget {
  const TransitOptionsScreen({super.key});

  @override
  State<TransitOptionsScreen> createState() => _TransitOptionsScreenState();
}

class _TransitOptionsScreenState extends State<TransitOptionsScreen> {
  RoutingOptions _options = RoutingOptions.defaults;
  ServerConfig _capabilities = ServerConfig.fallback;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final options = await RoutingOptionsService.load();
    // Falls back to the published Transitous limits when unavailable, so the
    // controls stay usable offline.
    final capabilities = await ServerCapabilitiesService.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _options = options;
      _capabilities = capabilities;
      _loaded = true;
    });
  }

  void _update(RoutingOptions options) {
    if (options == _options) return;
    setState(() => _options = options);
    RoutingOptionsService.save(options);
  }

  /// Selected modes as a set, treating "none stored" as "all of them" so the
  /// category toggles read correctly.
  Set<TransitMode> get _selectedModes => _options.transitModes.isEmpty
      ? {..._allGroupedModes}
      : _options.transitModes.toSet();

  bool _isGroupSelected(_ModeGroup group) =>
      group.modes.every(_selectedModes.contains);

  void _toggleGroup(_ModeGroup group) {
    final selected = {..._selectedModes};
    if (_isGroupSelected(group)) {
      selected.removeAll(group.modes);
    } else {
      selected.addAll(group.modes);
    }
    _update(
      _options.copyWith(
        // Everything selected is the same as no restriction; storing the full
        // list would pin the set to the modes this build knows about.
        transitModes: selected.length >= _allGroupedModes.length
            ? const []
            : selected.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ThemeProvider>().accentColor;

    return AppPageScaffold(
      title: 'Transit options',
      scrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconHeader(
            icon: LucideIcons.settings2,
            title: 'Tune your defaults',
            subtitle: 'Improve the default routing settings.',
            iconColor: accent,
            backgroundColor: accent.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 28),
          // Everything below reads _options, so waiting avoids showing
          // defaults for a frame and writing them back on the first tap.
          if (!_loaded)
            const SizedBox(height: 200)
          else ...[
            _buildModesCard(context),
            const SizedBox(height: 28),
            TransitOptionsRequirementsCard(
              options: _options,
              capabilities: _capabilities,
              onChanged: _update,
            ),
            const SizedBox(height: 28),
            TransitOptionsViaStopsCard(options: _options, onChanged: _update),
            const SizedBox(height: 28),
            TransitOptionsTransferLimitCard(
              options: _options,
              onChanged: _update,
            ),
            const SizedBox(height: 28),
            _buildTransferBufferCard(context),
            const SizedBox(height: 28),
            TransitOptionsStreetLegsCard(
              options: _options,
              capabilities: _capabilities,
              onChanged: _update,
            ),
            const SizedBox(height: 28),
            _buildWalkingCard(context),
            const SizedBox(height: 28),
            TransitOptionsTerrainCard(
              options: _options,
              capabilities: _capabilities,
              onChanged: _update,
            ),
            if (Environment.showBackendSettings) ...[
              const SizedBox(height: 28),
              const TransitOptionsBackendCard(),
            ],
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildModesCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Transit modes'),
        const SizedBox(height: 12),
        Text(
          'Select those you wish to use.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.black.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final width = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final group in _modeGroups)
                  SizedBox(
                    width: group.label == 'Others'
                        ? constraints.maxWidth
                        : width,
                    child: SelectableIconCard(
                      label: group.label,
                      icon: _categoryIcon(group.label),
                      selected: _isGroupSelected(group),
                      onTap: () => _toggleGroup(group),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWalkingCard(BuildContext context) {
    const presets = [3.6, 4.8, 5.8];
    final accent = AppColors.accentOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Walking pace'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.timer, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    '${_options.walkingSpeedKmh.toStringAsFixed(1)} km/h',
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
                  for (var i = 0; i < presets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: QuickValueCard(
                        value: '${presets[i].toStringAsFixed(1)} km/h',
                        selected:
                            (_options.walkingSpeedKmh - presets[i]).abs() <
                            0.05,
                        onTap: () => _update(
                          _options.copyWith(walkingSpeedKmh: presets[i]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              StepperSelector(
                value: _options.walkingSpeedKmh,
                minValue: 2.0,
                maxValue: 7.0,
                step: 0.1,
                label: 'km/h',
                displayBuilder: (value) => value.toStringAsFixed(1),
                onChanged: (value) => _update(
                  _options.copyWith(
                    walkingSpeedKmh: double.parse(value.toStringAsFixed(1)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferBufferCard(BuildContext context) {
    const presets = [0, 3, 5, 10];
    final minutes = _options.additionalTransferTime.inMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Transfer buffer'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.clock4,
                    size: 18,
                    color: AppColors.accentOf(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    minutes == 0 ? 'No extra time' : '$minutes minute buffer',
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
                  for (var i = 0; i < presets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: QuickValueCard(
                        value: '${presets[i]} min',
                        selected: minutes == presets[i],
                        onTap: () => _update(
                          _options.copyWith(
                            additionalTransferTime: Duration(
                              minutes: presets[i],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              StepperSelector(
                value: minutes.toDouble(),
                minValue: 0,
                maxValue: 30,
                step: 1,
                label: 'min',
                displayBuilder: (value) => value.round().toString(),
                onChanged: (value) => _update(
                  _options.copyWith(
                    additionalTransferTime: Duration(minutes: value.round()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _categoryIcon(String label) {
  switch (label) {
    case 'Trains':
      return LucideIcons.trainFront;
    case 'Metro':
      return LucideIcons.trainFrontTunnel;
    case 'Tram':
      return LucideIcons.tramFront;
    case 'Bus':
      return LucideIcons.bus;
    case 'Walking':
      return LucideIcons.footprints;
    case 'Ferries':
      return LucideIcons.ship;
    case 'Lifts':
      return LucideIcons.cableCar;
    case 'Flights':
      return LucideIcons.planeTakeoff;
    case 'Others':
      return LucideIcons.sparkles;
    default:
      return LucideIcons.layers;
  }
}
