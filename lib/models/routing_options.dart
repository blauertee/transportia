import '../api/params/plan_params.dart';
import 'transitous/enums.dart';

/// A stop the user wants the journey to pass through.
class ViaStopOption {
  const ViaStopOption({
    required this.stopId,
    required this.name,
    this.minimumStay = Duration.zero,
  });

  /// Feed-prefixed stop id, as the geocoder returns it. A bare GTFS id is
  /// rejected by the server.
  final String stopId;

  /// Shown in the UI; not sent to the server.
  final String name;

  /// Zero lets the journey pass through without stopping, which often finds
  /// better connections than requiring a wait.
  final Duration minimumStay;

  ViaStopOption copyWith({Duration? minimumStay}) => ViaStopOption(
    stopId: stopId,
    name: name,
    minimumStay: minimumStay ?? this.minimumStay,
  );

  Map<String, dynamic> toJson() => {
    'stopId': stopId,
    'name': name,
    'minimumStayMinutes': minimumStay.inMinutes,
  };

  static ViaStopOption? fromJson(Map<String, dynamic> json) {
    final stopId = json['stopId'];
    if (stopId is! String || stopId.isEmpty) return null;
    return ViaStopOption(
      stopId: stopId,
      name: json['name'] as String? ?? stopId,
      minimumStay: Duration(minutes: json['minimumStayMinutes'] as int? ?? 0),
    );
  }
}

/// The user's routing preferences, as offered by the Transit options screen.
///
/// Everything here maps onto a `/plan` parameter. Defaults match what the
/// server does when the parameter is absent, so an untouched configuration
/// produces the same query the app sent before these options existed.
class RoutingOptions {
  const RoutingOptions({
    this.transitModes = const [],
    this.useRoutedTransfers = true,
    this.wheelchairAccessibleOnly = false,
    this.bikeCarriageOverride,
    this.carCarriageOverride,
    this.noCompulsoryReservation = false,
    this.via = const [],
    this.maxTransfers,
    this.additionalTransferTime = Duration.zero,
    this.firstMileMode = TransitMode.walk,
    this.maxFirstMileTime = const Duration(minutes: 15),
    this.lastMileMode = TransitMode.walk,
    this.maxLastMileTime = const Duration(minutes: 15),
    this.directMode = TransitMode.walk,
    this.maxDirectTime = const Duration(minutes: 30),
    this.walkingSpeedKmh = _defaultWalkingSpeedKmh,
    this.cyclingSpeedKmh = _defaultCyclingSpeedKmh,
    this.elevationCosts = ElevationCosts.none,
  });

  /// MOTIS's own default pedestrian speed, 1.34 m/s.
  static const double _defaultWalkingSpeedKmh = 4.8;

  /// MOTIS's own default cycling speed, 4.2 m/s.
  static const double _defaultCyclingSpeedKmh = 15.1;

  static const RoutingOptions defaults = RoutingOptions();

  /// Transit modes to use. Empty means all of them.
  final List<TransitMode> transitModes;

  /// Route transfers over the street network rather than using the feed's
  /// transfer times.
  final bool useRoutedTransfers;

  /// Restrict street legs to step-free paths.
  final bool wheelchairAccessibleOnly;

  /// Whether to demand a service that carries bicycles.
  ///
  /// Null means "follow [bikeAtBothEnds]" — picking a bike at both ends says
  /// the bike is travelling with you, so carriage follows without being asked
  /// for. Non-null means the rider decided, and their choice holds until the
  /// mile modes stop implying anything.
  ///
  /// Turning it off with a bike at both ends is a real request: the bike is
  /// coming, but you would rather walk it onto a service that does not
  /// advertise carriage.
  final bool? bikeCarriageOverride;

  /// Same rule for taking a car aboard, where carriage means motorail.
  final bool? carCarriageOverride;

  /// A bike is chosen for both the first and the last mile, so it travels
  /// with the rider rather than being left at the origin station.
  bool get bikeAtBothEnds =>
      firstMileMode == TransitMode.bike && lastMileMode == TransitMode.bike;

  bool get carAtBothEnds =>
      firstMileMode == TransitMode.car && lastMileMode == TransitMode.car;

  /// The value actually sent.
  ///
  /// Gated on the condition as well as the override: demanding a service that
  /// carries bicycles while walking to the station asks for room for a bike
  /// that is not coming. Copies clear a stale override, and this keeps a
  /// restored one from forcing carriage with no control on screen to undo it.
  bool get requireBikeTransport =>
      bikeAtBothEnds && (bikeCarriageOverride ?? true);

  bool get requireCarTransport =>
      carAtBothEnds && (carCarriageOverride ?? true);

  /// True when the rider set carriage by hand rather than inheriting it.
  bool get bikeCarriageIsManual => bikeCarriageOverride != null;

  /// Exclude services that require a reservation.
  final bool noCompulsoryReservation;

  final List<ViaStopOption> via;

  /// Null leaves it to the server.
  final int? maxTransfers;

  /// Buffer added to every transfer on top of the feed's own time.
  final Duration additionalTransferTime;

  /// How to reach the first stop, and the budget for it.
  final TransitMode firstMileMode;
  final Duration maxFirstMileTime;

  /// How to travel from the last stop, and the budget for it.
  final TransitMode lastMileMode;
  final Duration maxLastMileTime;

  /// Mode and budget for a transit-free itinerary.
  final TransitMode directMode;
  final Duration maxDirectTime;

  /// Stored in km/h because that is what the UI shows; converted to m/s on
  /// the way out.
  final double walkingSpeedKmh;
  final double cyclingSpeedKmh;

  /// How hard to avoid inclines. Needs a server with elevation data.
  final ElevationCosts elevationCosts;

  /// Modes the street legs may use, i.e. the ones a speed applies to.
  static const List<TransitMode> streetModeChoices = [
    TransitMode.walk,
    TransitMode.bike,
    TransitMode.rental,
    TransitMode.car,
    TransitMode.carParking,
    TransitMode.carDropoff,
  ];

  RoutingOptions copyWith({
    List<TransitMode>? transitModes,
    bool? useRoutedTransfers,
    bool? wheelchairAccessibleOnly,
    bool? bikeCarriageOverride,
    bool? carCarriageOverride,
    bool clearCarriageOverrides = false,
    bool? noCompulsoryReservation,
    List<ViaStopOption>? via,
    int? maxTransfers,
    bool clearMaxTransfers = false,
    Duration? additionalTransferTime,
    TransitMode? firstMileMode,
    Duration? maxFirstMileTime,
    TransitMode? lastMileMode,
    Duration? maxLastMileTime,
    TransitMode? directMode,
    Duration? maxDirectTime,
    double? walkingSpeedKmh,
    double? cyclingSpeedKmh,
    ElevationCosts? elevationCosts,
  }) {
    final nextFirst = firstMileMode ?? this.firstMileMode;
    final nextLast = lastMileMode ?? this.lastMileMode;
    final keepsBike =
        nextFirst == TransitMode.bike && nextLast == TransitMode.bike;
    final keepsCar =
        nextFirst == TransitMode.car && nextLast == TransitMode.car;

    return RoutingOptions(
      transitModes: transitModes ?? this.transitModes,
      useRoutedTransfers: useRoutedTransfers ?? this.useRoutedTransfers,
      wheelchairAccessibleOnly:
          wheelchairAccessibleOnly ?? this.wheelchairAccessibleOnly,
      bikeCarriageOverride: clearCarriageOverrides || !keepsBike
          ? null
          : (bikeCarriageOverride ?? this.bikeCarriageOverride),
      carCarriageOverride: clearCarriageOverrides || !keepsCar
          ? null
          : (carCarriageOverride ?? this.carCarriageOverride),
      noCompulsoryReservation:
          noCompulsoryReservation ?? this.noCompulsoryReservation,
      via: via ?? this.via,
      maxTransfers: clearMaxTransfers
          ? null
          : (maxTransfers ?? this.maxTransfers),
      additionalTransferTime:
          additionalTransferTime ?? this.additionalTransferTime,
      firstMileMode: firstMileMode ?? this.firstMileMode,
      maxFirstMileTime: maxFirstMileTime ?? this.maxFirstMileTime,
      lastMileMode: lastMileMode ?? this.lastMileMode,
      maxLastMileTime: maxLastMileTime ?? this.maxLastMileTime,
      directMode: directMode ?? this.directMode,
      maxDirectTime: maxDirectTime ?? this.maxDirectTime,
      walkingSpeedKmh: walkingSpeedKmh ?? this.walkingSpeedKmh,
      cyclingSpeedKmh: cyclingSpeedKmh ?? this.cyclingSpeedKmh,
      elevationCosts: elevationCosts ?? this.elevationCosts,
    );
  }

  /// Builds the `/plan` query for a journey between two coordinates.
  ///
  /// Values left at their default are omitted, so the server keeps deciding
  /// them and a future change upstream is not pinned by this app.
  PlanParams toPlanParams({
    required String fromPlace,
    required String toPlace,
    DateTime? time,
    bool? arriveBy,
    String? pageCursor,
  }) {
    return PlanParams(
      fromPlace: fromPlace,
      toPlace: toPlace,
      time: time,
      arriveBy: arriveBy,
      pageCursor: pageCursor,
      withFares: true,
      useRoutedTransfers: useRoutedTransfers,
      pedestrianProfile: wheelchairAccessibleOnly
          ? PedestrianProfile.wheelchair
          : null,
      requireBikeTransport: requireBikeTransport ? true : null,
      requireCarTransport: requireCarTransport ? true : null,
      noCompulsoryReservation: noCompulsoryReservation ? true : null,
      via: [
        for (final stop in via)
          ViaStop(stopId: stop.stopId, minimumStay: stop.minimumStay),
      ],
      maxTransfers: maxTransfers,
      additionalTransferTime: additionalTransferTime > Duration.zero
          ? additionalTransferTime
          : null,
      transitModes: transitModes,
      preTransitModes: [firstMileMode],
      maxPreTransitTime: maxFirstMileTime,
      postTransitModes: [lastMileMode],
      maxPostTransitTime: maxLastMileTime,
      directModes: [directMode],
      maxDirectTime: maxDirectTime,
      pedestrianSpeed: _msFrom(walkingSpeedKmh, _defaultWalkingSpeedKmh),
      cyclingSpeed: _msFrom(cyclingSpeedKmh, _defaultCyclingSpeedKmh),
      elevationCosts: elevationCosts == ElevationCosts.none
          ? null
          : elevationCosts,
    );
  }

  /// km/h to m/s, or null when the value is the server's own default.
  static double? _msFrom(double kmh, double defaultKmh) {
    if ((kmh - defaultKmh).abs() < 0.05) return null;
    return double.parse((kmh / 3.6).toStringAsFixed(3));
  }

  Map<String, dynamic> toJson() => {
    'transitModes': [for (final mode in transitModes) mode.wireName],
    'useRoutedTransfers': useRoutedTransfers,
    'wheelchairAccessibleOnly': wheelchairAccessibleOnly,
    'bikeCarriageOverride': bikeCarriageOverride,
    'carCarriageOverride': carCarriageOverride,
    'noCompulsoryReservation': noCompulsoryReservation,
    'via': [for (final stop in via) stop.toJson()],
    'maxTransfers': maxTransfers,
    'additionalTransferTimeMinutes': additionalTransferTime.inMinutes,
    'firstMileMode': firstMileMode.wireName,
    'maxFirstMileTimeMinutes': maxFirstMileTime.inMinutes,
    'lastMileMode': lastMileMode.wireName,
    'maxLastMileTimeMinutes': maxLastMileTime.inMinutes,
    'directMode': directMode.wireName,
    'maxDirectTimeMinutes': maxDirectTime.inMinutes,
    'walkingSpeedKmh': walkingSpeedKmh,
    'cyclingSpeedKmh': cyclingSpeedKmh,
    'elevationCosts': elevationCosts.wireName,
  };

  /// Reads stored options, falling back per field rather than as a whole, so
  /// a value written by a different version cannot reset everything else.
  factory RoutingOptions.fromJson(Map<String, dynamic> json) {
    const fallback = RoutingOptions.defaults;
    return RoutingOptions(
      transitModes: _modes(json['transitModes']),
      useRoutedTransfers:
          json['useRoutedTransfers'] as bool? ?? fallback.useRoutedTransfers,
      wheelchairAccessibleOnly:
          json['wheelchairAccessibleOnly'] as bool? ??
          fallback.wheelchairAccessibleOnly,
      // Older stores wrote a plain flag; a true one is a decision worth
      // keeping, a false one is indistinguishable from the default.
      bikeCarriageOverride:
          json['bikeCarriageOverride'] as bool? ??
          (json['requireBikeTransport'] == true ? true : null),
      carCarriageOverride:
          json['carCarriageOverride'] as bool? ??
          (json['requireCarTransport'] == true ? true : null),
      noCompulsoryReservation:
          json['noCompulsoryReservation'] as bool? ??
          fallback.noCompulsoryReservation,
      via: _via(json['via']),
      maxTransfers: json['maxTransfers'] as int?,
      additionalTransferTime: _minutes(
        json['additionalTransferTimeMinutes'],
        fallback.additionalTransferTime,
      ),
      firstMileMode: _mode(json['firstMileMode'], fallback.firstMileMode),
      maxFirstMileTime: _minutes(
        json['maxFirstMileTimeMinutes'],
        fallback.maxFirstMileTime,
      ),
      lastMileMode: _mode(json['lastMileMode'], fallback.lastMileMode),
      maxLastMileTime: _minutes(
        json['maxLastMileTimeMinutes'],
        fallback.maxLastMileTime,
      ),
      directMode: _mode(json['directMode'], fallback.directMode),
      maxDirectTime: _minutes(
        json['maxDirectTimeMinutes'],
        fallback.maxDirectTime,
      ),
      walkingSpeedKmh:
          (json['walkingSpeedKmh'] as num?)?.toDouble() ??
          fallback.walkingSpeedKmh,
      cyclingSpeedKmh:
          (json['cyclingSpeedKmh'] as num?)?.toDouble() ??
          fallback.cyclingSpeedKmh,
      elevationCosts:
          ElevationCosts.fromWire(json['elevationCosts']) ??
          fallback.elevationCosts,
    );
  }

  static List<TransitMode> _modes(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (TransitMode.fromWire(entry) case final mode?) mode,
    ];
  }

  static TransitMode _mode(Object? raw, TransitMode fallback) =>
      TransitMode.fromWire(raw) ?? fallback;

  static Duration _minutes(Object? raw, Duration fallback) =>
      raw is int ? Duration(minutes: raw) : fallback;

  /// Value equality, so a screen can tell whether anything actually changed
  /// before writing. Compares the serialised form rather than field by field,
  /// which keeps it correct as options are added.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutingOptions &&
          _encoded(toJson()) == _encoded(other.toJson()));

  @override
  int get hashCode => _encoded(toJson()).hashCode;

  static String _encoded(Map<String, dynamic> json) =>
      json.entries.map((e) => '${e.key}=${_stringify(e.value)}').join('&');

  static String _stringify(Object? value) {
    if (value is List) return value.map(_stringify).join(',');
    if (value is Map) {
      return value.entries.map((e) => '${e.key}:${e.value}').join('|');
    }
    return '$value';
  }

  static List<ViaStopOption> _via(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map<String, dynamic>)
          if (ViaStopOption.fromJson(entry) case final stop?) stop,
    ];
  }
}
