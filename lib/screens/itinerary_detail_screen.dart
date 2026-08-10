import 'dart:async';
import 'dart:convert';

import 'package:transportia/widgets/load_more_button.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/itinerary.dart';
import '../models/transit_mode_group.dart';
import '../models/saved_trip.dart';
import '../models/time_selection.dart';
import '../providers/theme_provider.dart';
import '../services/itinerary_refresh_service.dart';
import '../utils/haptics.dart';
import '../services/routing_options_service.dart';
import '../services/transitous_geocode_service.dart';
import '../theme/app_colors.dart';
import '../theme/journey_metrics.dart';
import '../utils/color_utils.dart';
import '../utils/custom_page_route.dart';
import '../utils/duration_formatter.dart';
import '../utils/itinerary_leg_utils.dart';
import '../utils/journey_colors.dart';
import '../utils/leg_helper.dart';
import '../utils/time_utils.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_card.dart';
import '../widgets/journey/spine_node.dart';
import '../widgets/journey/spine_row.dart';
import '../widgets/info_chip.dart';
import '../widgets/last_updated_footer.dart';
import '../widgets/save_trip_button.dart';
import '../widgets/stop_departures_sheet.dart';
import 'connection_info_screen.dart';
import 'itinerary_list_screen.dart';
import 'itinerary_map_screen.dart';

/// Opens the [StopDeparturesSheet] for a tapped stop. Passed down through
/// the leg widgets so they don't need to know how the sheet is presented.
typedef OpenStopSheet =
    void Function({
      required String? stopId,
      required String stopName,
      required DateTime referenceTime,
    });

/// The first line of a node's text, and the first line of a stop's.
///
/// Both carry an explicit `height` because [SpineRow] centres its columns on
/// the node using a line height the caller states — measuring the real one
/// would need an intrinsic pass, and the height of an expanding leg is
/// mid-animation exactly when that would run.
const double kSpineNameLineHeight = 20;
const double kSpineStopLineHeight = 18;

/// A delay sits on its own line under the time it belongs to. Explicit for
/// the same reason: [SpineTimes] has to know how tall its own stack is.
const double kSpineDelayLineHeight = 14;

/// Where a minor stop's dot sits, measured from the row's top. Tighter than a
/// node's, because a passed-through stop is a smaller mark and does not need
/// a ring's worth of room.
const double kSpineMinorNodeCenter = 11;

const TextStyle kSpineNameStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: kSpineNameLineHeight / 16,
);

const TextStyle kSpineStopStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w400,
  height: kSpineStopLineHeight / 15,
);

/// When a service is at a point on the line, and when it leaves again.
///
/// Where the two differ the service waited there, and both are worth printing.
/// The **departure** is the one that carries the row: it is what you can still
/// catch, so it takes the row's anchor and its weight, and the arrival hangs
/// above it in grey. Where only one time is known, that one is the departure's
/// place.
class SpineTimes extends StatelessWidget {
  const SpineTimes({
    super.key,
    this.arrival,
    this.departure,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.compact = false,
  });

  final DateTime? arrival;
  final DateTime? departure;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;

  /// Stacks the two times instead of running them across, for the narrow
  /// column an intermediate stop gets.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final arrival = _StopTime.from(this.arrival, scheduledArrival);
    final departure = _StopTime.from(this.departure, scheduledDeparture);

    final showBoth =
        arrival != null &&
        departure != null &&
        arrival.scheduled != departure.scheduled;

    // The last entry is the one that leaves, whether or not an arrival came
    // before it.
    final times = showBoth
        ? [arrival, departure]
        : [if (departure != null) departure else if (arrival != null) arrival];
    if (times.isEmpty) return const SizedBox.shrink();

    final lineHeight = compact ? kSpineStopLineHeight : kSpineNameLineHeight;

    // On a leg, everything above the departure is lifted out of the row so the
    // departure — not the arrival — ends up level with the node and the stop
    // name. Height rather than layout, because the row cannot afford an
    // intrinsic pass; every style here sets an explicit height so this is
    // exact.
    //
    // A stop between two ends of a leg is left alone. Lifting there would
    // float its arrival up towards the station above, which is the one place
    // the pair must not look like it belongs.
    var above = 0.0;
    if (!compact) {
      for (final time in times.take(times.length - 1)) {
        above += lineHeight;
        if (time.delay != null) above += kSpineDelayLineHeight;
      }
    }

    return Transform.translate(
      offset: Offset(0, -above),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final time in times) ...[
            Text(
              formatTime(time.scheduled),
              // A time is one line. Wrapping it would break the arithmetic
              // that puts the departure on the row's anchor, and half a clock
              // reading over two lines is worse than a tight fit.
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: time == times.last
                    ? FontWeight.w700
                    : FontWeight.w500,
                height: lineHeight / (compact ? 13 : 14),
                color: AppColors.black.withValues(
                  alpha: time == times.last ? 0.9 : 0.45,
                ),
              ),
            ),
            if (time.delay case final delay?)
              Text(
                formatDelay(delay),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: kSpineDelayLineHeight / 11.5,
                  color: delayColor(delay),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class ItineraryDetailScreen extends StatefulWidget {
  final Itinerary itinerary;

  /// Set when this screen is showing a stored connection rather than a
  /// result the user just searched for.
  ///
  /// A stored connection is stale by definition, so it is re-checked on
  /// open and the screen says what that check found.
  final SavedTrip? savedTrip;

  /// The places the user searched for, so saving from here names the trip
  /// the same way saving from the results list does.
  final String? fromName;
  final String? toName;

  const ItineraryDetailScreen({
    super.key,
    required this.itinerary,
    this.savedTrip,
    this.fromName,
    this.toName,
  });

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  bool _isSharing = false;
  late Itinerary _itinerary;
  DateTime? _lastUpdated;
  bool _isRefreshing = false;
  Timer? _agoTicker;
  ItineraryFreshness? _freshness;

  @override
  void initState() {
    super.initState();
    _itinerary = widget.itinerary;

    if (widget.savedTrip == null) {
      // A search result was fetched moments ago, so it is current.
      _lastUpdated = DateTime.now();
    } else {
      // A saved trip has not been checked since it was stored. Say nothing
      // about how fresh it is until a refresh comes back.
      _lastUpdated = null;
      unawaited(_refreshRealTimeInfo());
    }

    _agoTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _agoTicker?.cancel();
    super.dispose();
  }

  void _openStopSheet({
    required String? stopId,
    required String stopName,
    required DateTime referenceTime,
  }) {
    if (stopId == null || stopId.isEmpty) return;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Stop departures',
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return StopDeparturesSheet(
          stopId: stopId,
          stopName: stopName,
          referenceTime: referenceTime,
          onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// Opens the journey map on one leg.
  ///
  /// Walking, cycling and changing are the legs whose shape is the whole
  /// question — which side of the station, which exit, how far — and the
  /// answer is on the map rather than in the row. Transit legs keep their tap
  /// for expanding the stops they call at.
  void _showLegOnMap(int displayLegIndex) {
    Haptics.lightTick();
    Navigator.of(context).push(
      CustomPageRoute(
        child: ItineraryMapScreen(
          itinerary: _itinerary,
          initialLegIndex: displayLegIndex,
        ),
      ),
    );
  }

  Future<void> _refreshRealTimeInfo() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    // The refresh re-plans, so it needs the settings the journey was planned
    // under; without them the server answers with its own defaults and the
    // street legs come back unrouted.
    final result = await ItineraryRefreshService.refresh(
      _itinerary,
      options: await RoutingOptionsService.load(),
    );

    if (!mounted) {
      _isRefreshing = false;
      return;
    }

    // Only move the timestamp when live data actually arrived, so a pull
    // that reached nothing does not read as a successful refresh.
    setState(() {
      _freshness = result.freshness;
      if (result.didRefresh) {
        _itinerary = result.itinerary;
        _lastUpdated = DateTime.now();
      }
    });

    _isRefreshing = false;
  }

  /// Re-plans the same journey, so the user has somewhere to go when the
  /// stored connection no longer works.
  void _findAlternatives(SavedTrip trip, {required DateTime departAt}) {
    Navigator.of(context).push(
      CustomPageRoute(
        child: ItineraryListScreen(
          fromLat: trip.fromLat,
          fromLon: trip.fromLon,
          toLat: trip.toLat,
          toLon: trip.toLon,
          fromSelection: TransitousLocationSuggestion(
            id: 'saved-from-${trip.id}',
            name: trip.fromName,
            lat: trip.fromLat,
            lon: trip.fromLon,
            type: 'PLACE',
          ),
          toSelection: TransitousLocationSuggestion(
            id: 'saved-to-${trip.id}',
            name: trip.toName,
            lat: trip.toLat,
            lon: trip.toLon,
            type: 'PLACE',
          ),
          timeSelection: TimeSelection(dateTime: departAt, isArriveBy: false),
        ),
      ),
    );
  }

  /// The next time today or tomorrow that this trip's departure comes
  /// round, for repeating a journey already taken.
  DateTime _nextOccurrence(DateTime departure) {
    final local = departure.toLocal();
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
      local.hour,
      local.minute,
    );
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// The one thing worth saying about a saved trip's current state, or null
  /// when it is simply live and on time.
  Widget? _savedTripNotice() {
    final trip = widget.savedTrip;
    if (trip == null) return null;

    if (trip.isPast) {
      return _SavedTripNotice(
        icon: LucideIcons.history,
        message: 'This trip has already happened.',
        actionLabel: 'Search again',
        onAction: () => _findAlternatives(
          trip,
          departAt: _nextOccurrence(trip.departureTime),
        ),
      );
    }

    final isCancelled =
        _freshness == ItineraryFreshness.changed ||
        _itinerary.legs.any((leg) => leg.cancelled);
    if (isCancelled) {
      return _SavedTripNotice(
        icon: LucideIcons.triangleAlert,
        message: 'This connection has changed.',
        actionLabel: 'Find alternatives',
        tint: AppColors.disrupted,
        onAction: () => _findAlternatives(trip, departAt: trip.departureTime),
      );
    }

    if (_freshness == ItineraryFreshness.scheduled) {
      return _SavedTripNotice(
        icon: LucideIcons.calendarClock,
        message: "Scheduled times — live data isn't available yet.",
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final displayLegs = buildDisplayLegs(_itinerary.legs);
    final savedTripNotice = _savedTripNotice();

    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomAppBar(
              title: 'Itinerary Details',
              onBackButtonPressed: () => Navigator.of(context).pop(),
              trailing: SaveTripButton(
                itinerary: _itinerary,
                fromName: widget.fromName ?? widget.savedTrip?.fromName,
                toName: widget.toName ?? widget.savedTrip?.toName,
              ),
            ),
            JourneyOverviewWidget(itinerary: _itinerary),
            if (savedTripNotice != null) savedTripNotice,
            Expanded(
              child: Builder(
                builder: (context) {
                  final hasTicketInfo = _itinerary.hasTicketInfo;
                  final ticketInsertIndex = hasTicketInfo ? 1 : 0;
                  final hasFinishCard = _itinerary.legs.isNotEmpty;
                  final legsInsertIndex = ticketInsertIndex;
                  final emptyMessageIndex = displayLegs.isEmpty
                      ? legsInsertIndex
                      : -1;
                  final legsEndIndex =
                      legsInsertIndex +
                      (displayLegs.isEmpty ? 1 : displayLegs.length);
                  final finishInsertIndex = legsEndIndex;
                  final shareIndex =
                      finishInsertIndex + (hasFinishCard ? 1 : 0);
                  final footerIndex = shareIndex + 1;
                  final totalItems = footerIndex + 1;

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: _refreshRealTimeInfo,
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            if (hasTicketInfo && index == 0) {
                              return TicketInfoCard(
                                ticketInfo: _itinerary.ticketInfo,
                              );
                            }

                            if (index == emptyMessageIndex) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    'No additional steps required for this journey.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            if (index >= legsInsertIndex &&
                                index < legsEndIndex) {
                              final legIndex = index - legsInsertIndex;
                              final entry = displayLegs[legIndex];
                              // A node belongs to the leg arriving at it as
                              // well as the one leaving it, and where those
                              // times differ you waited there.
                              final previous = legIndex > 0
                                  ? displayLegs[legIndex - 1].leg
                                  : null;
                              if (entry.isTransfer) {
                                return TransferLegCard(
                                  leg: entry.leg,
                                  previousLeg: previous,
                                  openStopSheet: _openStopSheet,
                                  onShowOnMap: () => _showLegOnMap(legIndex),
                                );
                              }
                              return LegDetailsWidget(
                                leg: entry.leg,
                                previousLeg: previous,
                                openStopSheet: _openStopSheet,
                                onShowOnMap: () => _showLegOnMap(legIndex),
                              );
                            }

                            if (hasFinishCard && index == finishInsertIndex) {
                              final finishLeg = _itinerary.legs.last;
                              return FinishLegCard(
                                leg: finishLeg,
                                arrivalTime: _itinerary.endTime,
                                totalDuration: _itinerary.duration,
                                openStopSheet: _openStopSheet,
                              );
                            }

                            if (index == shareIndex) {
                              return LoadMoreButton(
                                onTap: _shareItinerary,
                                isLoading: _isSharing,
                                label: 'Share this trip',
                                icon: LucideIcons.share2,
                              );
                            }

                            if (index == footerIndex) {
                              return LastUpdatedFooter(
                                lastUpdated: _lastUpdated,
                              );
                            }

                            return const SizedBox.shrink();
                          }, childCount: totalItems),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareItinerary() async {
    if (_isSharing) return;

    final legs = _itinerary.legs;
    if (legs.isEmpty) {
      debugPrint('Cannot share itinerary without any legs.');
      return;
    }

    setState(() => _isSharing = true);

    try {
      final firstLeg = legs.first;
      final lastLeg = legs.last;

      final payload = jsonEncode({
        'from': {'lat': firstLeg.fromLat, 'lon': firstLeg.fromLon},
        'to': {'lat': lastLeg.toLat, 'lon': lastLeg.toLon},
        'time': _itinerary.startTime.toIso8601String(),
      });

      final encoded = base64Url.encode(utf8.encode(payload));
      final shareUrl = 'https://transportia.wafler.one/trip/$encoded';

      await SharePlus.instance.share(ShareParams(text: shareUrl));
    } catch (error, stackTrace) {
      debugPrint('Failed to share itinerary: $error');
      debugPrint('$stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }
}

/// A single line about a saved trip's current state, with the one action
/// that makes sense for it.
class _SavedTripNotice extends StatelessWidget {
  const _SavedTripNotice({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tint,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.accentOf(context);
    final actionLabel = this.actionLabel;

    return CustomCard.filled(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      backgroundColor: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.black.withValues(alpha: 0.8),
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(LucideIcons.chevronRight, size: 15, color: color),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class JourneyOverviewWidget extends StatelessWidget {
  final Itinerary itinerary;

  const JourneyOverviewWidget({super.key, required this.itinerary});

  @override
  Widget build(BuildContext context) {
    // No box. It is the head of the journey, not a notice about it, and the
    // spine below it is boxless too — a card here made the screen read as a
    // card followed by a drawing. A rule and some air separate it instead,
    // and its padding matches the rows' so the map icon lands on the same
    // right edge as every leg's.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        JourneyMetrics.screenPadding,
        4,
        JourneyMetrics.screenPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Departure',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTime(itinerary.startTime),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Icon(LucideIcons.clock, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      formatDuration(itinerary.duration),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Arrival',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTime(itinerary.endTime),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildStatChip(
                    LucideIcons.repeat,
                    '${itinerary.transfers}',
                    itinerary.transfers == 1 ? 'transfer' : 'transfers',
                  ),
                  if (itinerary.walkingDistance > 0)
                    _buildStatChip(
                      LucideIcons.flame,
                      '${itinerary.calories}',
                      'cal',
                    ),
                  if (itinerary.fare != null && itinerary.fare!.amount > 0)
                    _buildStatChip(
                      LucideIcons.banknote,
                      '${itinerary.fare!.amount.toStringAsFixed(2)}',
                      itinerary.fare!.currency,
                    ),
                  if (itinerary.alertsCount > 0)
                    _buildStatChip(
                      LucideIcons.triangleAlert,
                      '${itinerary.alertsCount}',
                      itinerary.alertsCount == 1 ? 'alert' : 'alerts',
                    ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    CustomPageRoute(
                      child: ItineraryMapScreen(itinerary: itinerary),
                    ),
                  );
                },
                child: Semantics(
                  button: true,
                  label: 'Show the whole journey on the map',
                  child: Icon(
                    LucideIcons.map,
                    // The same size the legs use, on the same edge.
                    size: 16,
                    color: AppColors.accentOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.black.withValues(alpha: 0.08)),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.black.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.black.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class TicketInfoCard extends StatefulWidget {
  final List<FareLegInfo> ticketInfo;

  const TicketInfoCard({super.key, required this.ticketInfo});

  @override
  State<TicketInfoCard> createState() => _TicketInfoCardState();
}

class _TicketInfoCardState extends State<TicketInfoCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: CustomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.ticket,
                  size: 18,
                  color: AppColors.accentOf(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ticket information',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16,
                  color: AppColors.accentOf(context),
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: SizedBox(
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x33000000)),
                  ),
                ),
              ),
              ...widget.ticketInfo.map(_buildFareLegOptions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFareLegOptions(FareLegInfo legInfo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (legInfo.routeBadges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    'Valid for',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black.withValues(alpha: 0.5),
                    ),
                  ),
                  ...legInfo.routeBadges.map(_buildRouteBadge),
                ],
              ),
            ),
          ...legInfo.options.map(_buildFareOption),
        ],
      ),
    );
  }

  Widget _buildRouteBadge(RouteBadge badge) {
    final routeColor = parseHexColor(badge.routeColor);
    final bg = routeColor ?? AppColors.accentOf(context);
    final txt =
        parseHexColor(badge.routeTextColor) ??
        (routeColor == null ? AppColors.solidWhite : AppColors.black);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        badge.name,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: txt),
      ),
    );
  }

  Widget _buildFareOption(FareOption option) {
    final label = option.products.map((p) => p.name).join(' + ');
    final price = option.products
        .map((p) => '${p.amount.toStringAsFixed(2)} ${p.currency}')
        .join(' + ');
    final media = option.products
        .map((p) => p.fareMediaName)
        .whereType<String>()
        .where((m) => m.isNotEmpty)
        .toSet()
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.black.withValues(alpha: 0.8),
                  ),
                ),
                if (media.isNotEmpty)
                  Text(
                    media,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.black.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class LegDetailsWidget extends StatefulWidget {
  final Leg leg;
  final OpenStopSheet openStopSheet;

  /// Used by street legs, whose row cannot show which way they actually go.
  final VoidCallback? onShowOnMap;

  /// The leg that arrives at this one's node.
  ///
  /// A node belongs to two legs at once — one gets in, the other leaves — and
  /// where those times differ you waited there. Without this the row could
  /// only show the departure, losing a time the old two-row card printed.
  final Leg? previousLeg;

  const LegDetailsWidget({
    super.key,
    required this.leg,
    required this.openStopSheet,
    this.onShowOnMap,
    this.previousLeg,
  });

  @override
  State<LegDetailsWidget> createState() => _LegDetailsWidgetState();
}

class _LegDetailsWidgetState extends State<LegDetailsWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isStreet = isStreetLeg(widget.leg.mode);
    final color = _legColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SpineRow(
          // The ring is the node: it says what you board here, and the line
          // grows out of its underside in that service's colour.
          node: SpineNode(
            icon: getLegIcon(widget.leg.mode),
            color: color,
            semanticLabel: getTransitModeName(widget.leg.mode),
          ),
          railColor: color,
          railDashed: isStreet,
          // The leg owns the line from its own ring down to the next one.
          railTopInset: JourneyMetrics.ring,
          firstLineHeight: kSpineNameLineHeight,
          time: _buildDepartureTimes(),
          meta: _buildMeta(context, isStreet: isStreet),
          body: _buildBody(context, isStreet: isStreet),
          // A street leg has no stops to unfold, so its tap is free for the
          // map; a transit leg's tap unfolds the stops it calls at.
          onTap: isStreet
              ? widget.onShowOnMap
              : () => setState(() => _isExpanded = !_isExpanded),
        ),
        if (_isExpanded && !isStreet) ..._buildStopRows(color),
      ],
    );
  }

  Color _legColor(BuildContext context) => legSpineColor(
    leg: widget.leg,
    background: AppColors.white,
    accent: AppColors.accentOf(context),
  );

  /// When this leg leaves, and when the one before it got in.
  ///
  /// A node is shared between the leg arriving at it and the leg leaving it.
  /// Where the two differ you waited there, and both are worth printing —
  /// dropping either would lose a time the old two-row card showed.
  Widget _buildDepartureTimes() {
    final previous = widget.previousLeg;
    return SpineTimes(
      arrival: previous?.endTime,
      scheduledArrival: previous?.scheduledEndTime,
      departure: widget.leg.startTime,
      scheduledDeparture: widget.leg.scheduledStartTime,
    );
  }

  /// The right-hand column: the platform to stand on, or the way to the map.
  Widget? _buildMeta(BuildContext context, {required bool isStreet}) {
    if (isStreet) {
      // The whole row has always opened the map; nothing said so.
      if (widget.onShowOnMap == null) return null;
      return Semantics(
        button: true,
        label: 'Show this leg on the map',
        child: Icon(
          LucideIcons.map,
          size: 16,
          color: AppColors.accentOf(context),
        ),
      );
    }
    return _buildDepartureTrack();
  }

  Widget _buildBody(BuildContext context, {required bool isStreet}) {
    final alerts = widget.leg.alerts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.openStopSheet(
            stopId: widget.leg.fromStopId,
            stopName: widget.leg.fromName,
            referenceTime: widget.leg.startTime,
          ),
          child: Text(
            widget.leg.fromName,
            style: kSpineNameStyle.copyWith(color: AppColors.black),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // The badge keeps its own width; the end station takes what is
            // left, so it sits a fixed margin after the line number.
            Flexible(child: _buildTitleWidget()),
            if (_buildSubtitle() case final subtitle?) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (alerts.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  LucideIcons.triangleAlert,
                  size: 14,
                  color: Color(0xFFFF8A00),
                ),
              ),
            Expanded(
              child: Text(
                _buildNoteLine(),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.5),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        if (!isStreet) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isExpanded ? 'Hide stops' : 'Show stops',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentOf(context),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: 14,
                color: AppColors.accentOf(context),
              ),
            ],
          ),
        ],
        if (_isExpanded) ...[
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...alerts.map(_buildAlertWidget),
          ],
          const SizedBox(height: 8),
          _buildMetadataSection(),
        ],
        const SizedBox(height: 14),
      ],
    );
  }

  /// The quiet line under the service: how long, how far, how many stops, and
  /// once the leg is open, which class of vehicle it is.
  String _buildNoteLine() {
    final parts = <String>[formatDuration(widget.leg.duration)];

    if (_isExpanded) parts.add(getTransitModeName(widget.leg.mode));

    final distance = widget.leg.distance;
    if (distance != null && distance > 0) {
      parts.add('${(distance / 1000).toStringAsFixed(2)} km');
    }

    final stops = widget.leg.intermediateStops.length;
    if (stops > 0) parts.add('$stops ${stops == 1 ? 'stop' : 'stops'}');

    return parts.join(' · ');
  }

  /// The line beside the service badge.
  ///
  /// Where it is going is what you check you are on the right one by. The
  /// class of vehicle rarely changes what you do, so it waits in the note
  /// line until the leg is opened.
  String? _buildSubtitle() {
    final headsign = widget.leg.headsign?.trim();
    if (headsign != null && headsign.isNotEmpty) return headsign;
    if (isStreetLeg(widget.leg.mode)) return null;
    return null;
  }

  /// The platform to stand on, or a mark that it is not known.
  ///
  /// Shown whenever the feed gives one, whatever the mode — a bus stop can
  /// have a bay number and it is just as useful. The placeholder is only for
  /// rail and metro, where an absent platform is a gap in the data rather
  /// than a mode that simply has none; a permanent grey dash on every tram
  /// would say nothing.
  Widget? _buildDepartureTrack() {
    final track = widget.leg.fromTrack?.trim();
    final hasTrack = track != null && track.isNotEmpty;
    if (!hasTrack && !_expectsATrack) return null;

    return Text(
      hasTrack ? 'Track $track' : 'Track —',
      style: TextStyle(
        fontSize: 13,
        fontWeight: hasTrack ? FontWeight.w600 : FontWeight.w500,
        color: AppColors.black.withValues(alpha: hasTrack ? 0.75 : 0.35),
      ),
    );
  }

  /// True for the modes that run to numbered platforms.
  bool get _expectsATrack {
    final mode = TransitMode.fromWire(widget.leg.mode);
    if (mode == null) return false;
    return TransitModeGroup.rail.modes.contains(mode) ||
        TransitModeGroup.metro.modes.contains(mode) ||
        mode == TransitMode.rail;
  }

  /// The stops the service calls at, dropped onto the line it already has.
  ///
  /// They are minor dots rather than rings: you change nothing there, so they
  /// must not compete with the nodes, which mark the places you act at. The
  /// leg's own first stop is not repeated — it is the ring above.
  List<Widget> _buildStopRows(Color color) {
    final stops = <_TimelineStop>[];

    for (final stop in widget.leg.intermediateStops) {
      stops.add(
        _TimelineStop(
          name: stop.name,
          stopId: stop.stopId,
          track: stop.track,
          arrival: stop.arrival,
          departure: stop.departure,
          scheduledArrival: stop.scheduledArrival,
          scheduledDeparture: stop.scheduledDeparture,
          cancelled: stop.cancelled,
        ),
      );
    }

    return [
      for (final stop in stops)
        SpineRow(
          node: SpineDot(color: color),
          nodeCenter: kSpineMinorNodeCenter,
          railColor: color,
          firstLineHeight: kSpineStopLineHeight,
          time: SpineTimes(
            arrival: stop.arrival,
            scheduledArrival: stop.scheduledArrival,
            departure: stop.departure,
            scheduledDeparture: stop.scheduledDeparture,
            compact: true,
          ),
          meta: _buildStopTrack(stop),
          body: _buildStopBody(stop),
          onTap: stop.stopId == null
              ? null
              : () => widget.openStopSheet(
                  stopId: stop.stopId,
                  stopName: stop.name,
                  referenceTime: stop.time ?? widget.leg.startTime,
                ),
        ),
    ];
  }

  Widget _buildStopBody(_TimelineStop stop) {
    return Padding(
      // Roomy enough that a stop's arrival and departure read as belonging to
      // the name above them rather than to the stop below.
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stop.name,
            style: kSpineStopStyle.copyWith(color: AppColors.black),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          if (stop.cancelled) ...[
            const SizedBox(height: 2),
            Text(
              'CANCELLED',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFFD32F2F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// No placeholder here: a dozen grey dashes down a timeline would be noise,
  /// and the node above already answers whether the platform you stand on is
  /// known.
  Widget? _buildStopTrack(_TimelineStop stop) {
    final track = stop.track?.trim();
    if (track == null || track.isEmpty) return null;
    return Text(
      'Track $track',
      style: TextStyle(
        fontSize: 12,
        color: AppColors.black.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildMetadataSection() {
    final metadata = <Widget>[];
    final departureDelay = _departureDelay;
    final arrivalDelay = _arrivalDelay;

    if (widget.leg.cancelled) {
      metadata.add(
        InfoChip(
          icon: LucideIcons.circleAlert,
          label: 'CANCELLED',
          tint: const Color(0xFFD32F2F),
        ),
      );
    }

    // No track chip: the departure platform now sits on the card's own row
    // and again against the first stop of the timeline, so a chip here would
    // be the third copy of one number.

    if (widget.leg.realTime) {
      metadata.add(const InfoChip(icon: LucideIcons.radio, label: 'Real-time'));
    }

    if (widget.leg.distance != null && widget.leg.distance! > 0) {
      metadata.add(
        InfoChip(
          icon: LucideIcons.ruler,
          label: '${(widget.leg.distance! / 1000).toStringAsFixed(2)} km',
        ),
      );
    }

    if (widget.leg.agencyName != null) {
      metadata.add(
        InfoChip(icon: LucideIcons.building, label: widget.leg.agencyName!),
      );
    }

    if (widget.leg.routeLongName != null &&
        widget.leg.routeLongName!.isNotEmpty) {
      metadata.add(
        InfoChip(icon: LucideIcons.route, label: widget.leg.routeLongName!),
      );
    }

    final hasDelay =
        (departureDelay != null && !departureDelay.isNegative) ||
        (arrivalDelay != null && !arrivalDelay.isNegative);
    final hasAhead =
        (departureDelay != null && departureDelay.isNegative) ||
        (arrivalDelay != null && arrivalDelay.isNegative);

    if (hasDelay) {
      metadata.add(
        const InfoChip(
          icon: LucideIcons.circleAlert,
          label: 'Delayed',
          tint: Color(0xFFB26A00),
        ),
      );
    }

    if (!hasDelay && hasAhead) {
      metadata.add(
        const InfoChip(
          icon: LucideIcons.check,
          label: 'Ahead',
          tint: Color(0xFF2E7D32),
        ),
      );
    }

    if (widget.leg.interlineWithPreviousLeg) {
      metadata.add(const InfoChip(icon: LucideIcons.link, label: 'Interlined'));
    }

    if (metadata.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: metadata);
  }

  Widget _buildAlertWidget(Alert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: 16,
            color: const Color(0xFFF57C00),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (alert.headerText != null && alert.headerText!.isNotEmpty)
                  Text(
                    alert.headerText!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.solidBlack,
                    ),
                  ),
                if (alert.descriptionText != null &&
                    alert.descriptionText!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    alert.descriptionText!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.solidBlack.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Duration? get _departureDelay =>
      computeDelay(widget.leg.scheduledStartTime, widget.leg.startTime);

  Duration? get _arrivalDelay =>
      computeDelay(widget.leg.scheduledEndTime, widget.leg.endTime);

  Widget _buildTitleWidget() {
    if (widget.leg.displayName != null) {
      final routeColor = parseHexColor(widget.leg.routeColor);
      final isWalkLeg = widget.leg.mode == 'WALK';
      final bg = routeColor ?? (isWalkLeg ? null : AppColors.accentOf(context));
      final txt =
          parseHexColor(widget.leg.routeTextColor) ??
          (routeColor == null && !isWalkLeg
              ? AppColors.solidWhite
              : AppColors.black);
      // Sized to its own text. An Align here would take the whole of the
      // width the Row offered it, which put every leg's end station at the
      // same x instead of a fixed margin after its own line number.
      final badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg ?? const Color(0x00000000),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.leg.displayName!.isNotEmpty
              ? widget.leg.displayName!
              : getTransitModeName(widget.leg.mode),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: txt,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
      final tripId = widget.leg.tripId;
      if (isWalkLeg || tripId == null || tripId.isEmpty) return badge;
      return GestureDetector(
        onTap: () {
          Navigator.of(
            context,
          ).push(CustomPageRoute(child: ConnectionInfoScreen(tripId: tripId)));
        },
        child: badge,
      );
    }
    return Text(
      getTransitModeName(widget.leg.mode),
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.black,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

/// Getting between two services, as its own stretch of the line.
///
/// Neutral and dotted, because a change belongs to no line: you are on foot
/// between two operators' services. What a rider needs here is how long they
/// have and which platform to end up on, so both lead.
class TransferLegCard extends StatelessWidget {
  final Leg leg;
  final OpenStopSheet openStopSheet;

  /// A change is a walk between platforms; where it goes is the question.
  final VoidCallback? onShowOnMap;

  /// The leg that arrives at this change. See [LegDetailsWidget.previousLeg].
  final Leg? previousLeg;

  const TransferLegCard({
    super.key,
    required this.leg,
    required this.openStopSheet,
    this.onShowOnMap,
    this.previousLeg,
  });

  @override
  Widget build(BuildContext context) {
    return SpineRow(
      node: const SpineNode(
        icon: LucideIcons.arrowLeftRight,
        color: kStreetLegColor,
        semanticLabel: 'Change',
      ),
      railColor: kStreetLegColor,
      railDashed: true,
      railTopInset: JourneyMetrics.ring,
      firstLineHeight: kSpineNameLineHeight,
      time: SpineTimes(
        arrival: previousLeg?.endTime,
        scheduledArrival: previousLeg?.scheduledEndTime,
        departure: leg.startTime,
        scheduledDeparture: leg.scheduledStartTime,
      ),
      meta: onShowOnMap == null
          ? null
          : Semantics(
              button: true,
              label: 'Show this change on the map',
              child: Icon(
                LucideIcons.map,
                size: 16,
                color: AppColors.accentOf(context),
              ),
            ),
      onTap: onShowOnMap,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openStopSheet(
                stopId: leg.fromStopId,
                stopName: leg.fromName,
                referenceTime: leg.startTime,
              ),
              child: Text(
                leg.fromName,
                style: kSpineNameStyle.copyWith(color: AppColors.black),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Change · ${formatDuration(leg.duration)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.black.withValues(alpha: 0.75),
              ),
            ),
            if (_platforms() case final platforms?) ...[
              const SizedBox(height: 3),
              Text(
                platforms,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
            if (leg.distance != null && leg.distance! > 0) ...[
              const SizedBox(height: 3),
              Text(
                'Approx. ${(leg.distance! / 1000).toStringAsFixed(2)} km walk',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Which platform to leave and which to end up on — the one thing a change
  /// is actually about, and only worth a line when the feed knows it.
  String? _platforms() {
    final from = leg.fromTrack?.trim();
    final to = leg.toTrack?.trim();
    final hasFrom = from != null && from.isNotEmpty;
    final hasTo = to != null && to.isNotEmpty;
    if (hasFrom && hasTo) return 'Track $from → Track $to';
    if (hasTo) return 'To Track $to';
    if (hasFrom) return 'From Track $from';
    return null;
  }
}

class FinishLegCard extends StatelessWidget {
  final Leg leg;
  final DateTime arrivalTime;
  final int totalDuration;
  final OpenStopSheet openStopSheet;

  const FinishLegCard({
    super.key,
    required this.leg,
    required this.arrivalTime,
    required this.totalDuration,
    required this.openStopSheet,
  });

  @override
  Widget build(BuildContext context) {
    final color = legSpineColor(
      leg: leg,
      background: AppColors.white,
      accent: AppColors.accentOf(context),
    );

    return SpineRow(
      node: SpineNode(
        icon: LucideIcons.flag,
        color: color,
        filled: true,
        semanticLabel: 'Journey end',
      ),
      firstLineHeight: kSpineNameLineHeight,
      time: SpineTimes(
        arrival: arrivalTime,
        scheduledArrival: leg.scheduledEndTime,
      ),
      meta: _buildTrack(),
      onTap: () => openStopSheet(
        stopId: leg.toStopId,
        stopName: leg.toName,
        referenceTime: leg.endTime,
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              leg.toName,
              style: kSpineNameStyle.copyWith(color: AppColors.black),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 4),
            Text(
              'Finish · ${formatDuration(totalDuration)} total',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildTrack() {
    final track = leg.toTrack?.trim();
    if (track == null || track.isEmpty) return null;
    return Text(
      'Track $track',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.black.withValues(alpha: 0.75),
      ),
    );
  }
}

class _TimelineStop {
  final String name;
  final String? stopId;
  final String? track;
  final bool cancelled;

  /// Both times, kept apart.
  ///
  /// At a stop where the service waits, when it gets in and when it leaves
  /// again are different facts and the second is the one you can still catch.
  /// The first stop has only a departure and the last only an arrival.
  final DateTime? arrival;
  final DateTime? departure;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;

  _TimelineStop({
    required this.name,
    this.stopId,
    this.track,
    this.cancelled = false,
    this.arrival,
    this.departure,
    this.scheduledArrival,
    this.scheduledDeparture,
  });

  /// What the row is keyed on when only one time is wanted.
  DateTime? get time => departure ?? arrival;
}

/// One printable time: what the timetable promised, and how far off it is.
class _StopTime {
  final DateTime scheduled;
  final Duration? delay;

  const _StopTime(this.scheduled, this.delay);

  /// Null when the feed gave neither a real-time nor a scheduled value.
  ///
  /// A stop with only a real-time value still prints — that time is simply
  /// both the promise and the fact, so there is no delay to show against it.
  static _StopTime? from(DateTime? actual, DateTime? scheduled) {
    final base = scheduled ?? actual;
    if (base == null) return null;
    return _StopTime(base, actual == null ? null : computeDelay(base, actual));
  }
}
