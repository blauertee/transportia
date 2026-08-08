import 'transitous/enums.dart';

/// The four transport groups the search screen offers as icons.
///
/// MOTIS has two dozen transit modes, and a rider does not think in that
/// vocabulary — they think "train, metro, bus, boat". These groups cover the
/// common cases; anything outside them is picked individually from
/// [TransitModeGroup.extras] and shown by name, so the icons plus the named
/// extras always add up to the whole selection.
enum TransitModeGroup {
  rail('Rail', [
    TransitMode.rail,
    TransitMode.highspeedRail,
    TransitMode.longDistance,
    TransitMode.nightRail,
    TransitMode.regionalRail,
    TransitMode.regionalFastRail,
    TransitMode.suburban,
  ]),

  /// Tram sits here rather than with [rail]: light rail and metro are the same
  /// kind of trip for a rider, and it keeps "Rail" meaning mainline.
  metro('Metro', [TransitMode.metro, TransitMode.subway, TransitMode.tram]),

  bus('Bus', [TransitMode.bus, TransitMode.coach]),

  boat('Boat', [TransitMode.ferry]);

  const TransitModeGroup(this.label, this.modes);

  final String label;
  final List<TransitMode> modes;

  /// Modes worth offering but not worth an icon of their own.
  static const List<TransitMode> extras = [
    TransitMode.airplane,
    TransitMode.funicular,
    TransitMode.aerialLift,
    TransitMode.odm,
    TransitMode.rideSharing,
    TransitMode.flex,
    TransitMode.other,
  ];

  /// Rider-facing name for one of the [extras].
  static String extraLabel(TransitMode mode) {
    switch (mode) {
      case TransitMode.airplane:
        return 'Flights';
      case TransitMode.funicular:
        return 'Funicular';
      case TransitMode.aerialLift:
      case TransitMode.arealLift:
      case TransitMode.cableCar:
        return 'Cable car';
      case TransitMode.odm:
        return 'On demand';
      case TransitMode.rideSharing:
        return 'Ride share';
      case TransitMode.flex:
        return 'Flexible';
      default:
        return 'Other';
    }
  }

  /// True when every mode of this group is in [selected].
  bool isFullyIn(Set<TransitMode> selected) => modes.every(selected.contains);
}

/// A transit selection as the search screen holds it: four group switches plus
/// whatever extras were ticked individually.
///
/// Kept as one type so the icon row, the chips, the summary line and
/// `toPlanParams()` cannot disagree about what is selected.
class TransitSelection {
  const TransitSelection({
    this.groups = const {
      TransitModeGroup.rail,
      TransitModeGroup.metro,
      TransitModeGroup.bus,
      TransitModeGroup.boat,
    },
    this.extras = const {},
  });

  final Set<TransitModeGroup> groups;
  final Set<TransitMode> extras;

  /// Everything on, nothing added — the state the server assumes when
  /// `transitModes` is absent.
  static const TransitSelection everything = TransitSelection();

  bool get isEverything =>
      groups.length == TransitModeGroup.values.length && extras.isEmpty;

  bool get isEmpty => groups.isEmpty && extras.isEmpty;

  bool has(TransitModeGroup group) => groups.contains(group);

  TransitSelection toggleGroup(TransitModeGroup group) => TransitSelection(
    groups: groups.contains(group)
        ? (Set.of(groups)..remove(group))
        : (Set.of(groups)..add(group)),
    extras: extras,
  );

  TransitSelection toggleExtra(TransitMode mode) => TransitSelection(
    groups: groups,
    extras: extras.contains(mode)
        ? (Set.of(extras)..remove(mode))
        : (Set.of(extras)..add(mode)),
  );

  /// Flat mode list for `/plan`.
  ///
  /// Empty when everything is on, because sending the full list would pin the
  /// set to the modes this build happens to know about.
  List<TransitMode> toModes() {
    if (isEverything) return const [];
    return [
      for (final group in TransitModeGroup.values)
        if (groups.contains(group)) ...group.modes,
      ...extras,
    ];
  }

  /// Rebuilds the selection from a stored flat list.
  ///
  /// A group counts as on when all of its modes are present, so a list this
  /// build cannot fully account for degrades to the groups it recognises plus
  /// named extras, rather than being discarded.
  factory TransitSelection.fromModes(List<TransitMode> modes) {
    if (modes.isEmpty) return everything;
    final selected = modes.toSet();
    return TransitSelection(
      groups: {
        for (final group in TransitModeGroup.values)
          if (group.isFullyIn(selected)) group,
      },
      extras: {
        for (final mode in TransitModeGroup.extras)
          if (selected.contains(mode)) mode,
      },
    );
  }

  /// One line naming what is on, for the collapsed section.
  ///
  /// Says "All transport" rather than listing four groups: enumerating them
  /// truncates mid-word in the common case where nothing has been excluded.
  String summary() {
    if (isEverything) return 'All transport';
    if (isEmpty) return 'No transport';
    final names = [
      for (final group in TransitModeGroup.values)
        if (groups.contains(group)) group.label,
      for (final mode in TransitModeGroup.extras)
        if (extras.contains(mode)) TransitModeGroup.extraLabel(mode),
    ];
    return names.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransitSelection &&
          other.groups.length == groups.length &&
          other.groups.containsAll(groups) &&
          other.extras.length == extras.length &&
          other.extras.containsAll(extras));

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(groups),
    Object.hashAllUnordered(extras),
  );
}
