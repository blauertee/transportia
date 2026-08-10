import 'dart:async';
import 'dart:convert';

import 'package:transportia/widgets/load_more_button.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timelines_plus/timelines_plus.dart';

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
import '../utils/color_utils.dart';
import '../utils/custom_page_route.dart';
import '../utils/duration_formatter.dart';
import '../utils/itinerary_leg_utils.dart';
import '../utils/leg_helper.dart';
import '../utils/time_utils.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_card.dart';
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
                              if (entry.isTransfer) {
                                return TransferLegCard(
                                  leg: entry.leg,
                                  openStopSheet: _openStopSheet,
                                  onShowOnMap: () => _showLegOnMap(legIndex),
                                );
                              }
                              return LegDetailsWidget(
                                leg: entry.leg,
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
    return CustomCard(
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
                child: Icon(
                  LucideIcons.map,
                  size: 20,
                  color: AppColors.accentOf(context),
                ),
              ),
            ],
          ),
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

  const LegDetailsWidget({
    super.key,
    required this.leg,
    required this.openStopSheet,
    this.onShowOnMap,
  });

  @override
  State<LegDetailsWidget> createState() => _LegDetailsWidgetState();
}

class _LegDetailsWidgetState extends State<LegDetailsWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isWalkLeg = widget.leg.mode == 'WALK';
    final scheduledStart =
        widget.leg.scheduledStartTime ?? widget.leg.startTime;
    final scheduledEnd = widget.leg.scheduledEndTime ?? widget.leg.endTime;
    final departureDelay = _departureDelay;
    final arrivalDelay = _arrivalDelay;

    return GestureDetector(
      // A street leg has no stops to unfold, so its tap is free for the map;
      // a transit leg's tap already unfolds the stops it calls at.
      onTap: isWalkLeg
          ? widget.onShowOnMap
          : () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
      child: CustomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildLegIcon(),
                const SizedBox(width: 8),
                Expanded(child: _buildTitleWidget()),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Above the duration, because it is the one thing on this
                    // card you have to act on before the leg starts.
                    if (_buildDepartureTrack() case final track?) ...[
                      track,
                      const SizedBox(height: 2),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.leg.alerts.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              LucideIcons.triangleAlert,
                              size: 16,
                              color: Color(0xFFFF8A00),
                            ),
                          ),
                        Text(
                          formatDuration(widget.leg.duration),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!isWalkLeg) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.accentOf(context),
                  ),
                ],
              ],
            ),
            if (_buildSubtitle() case final subtitle?) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ],

            if (!_isExpanded) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => widget.openStopSheet(
                  stopId: widget.leg.fromStopId,
                  stopName: widget.leg.fromName,
                  referenceTime: widget.leg.startTime,
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.arrowRight, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${formatTime(scheduledStart)} - ${widget.leg.fromName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.black.withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (departureDelay != null)
                      _DelayChip(label: formatDelay(departureDelay)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => widget.openStopSheet(
                  stopId: widget.leg.toStopId,
                  stopName: widget.leg.toName,
                  referenceTime: widget.leg.endTime,
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.arrowDown, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${formatTime(scheduledEnd)} - ${widget.leg.toName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.black.withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (arrivalDelay != null)
                      _DelayChip(label: formatDelay(arrivalDelay)),
                  ],
                ),
              ),
            ],

            if (_isExpanded && !isWalkLeg) ...[
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
              _buildTransitTimelineContent(),
            ],
          ],
        ),
      ),
    );
  }

  /// The line under the title.
  ///
  /// Collapsed, a transit leg gives only where it is going: which class of
  /// train it is rarely changes what you do, and the destination is what you
  /// check you are on the right one by. The class joins it once the card is
  /// open. Null drops the line rather than leaving an empty band.
  String? _buildSubtitle() {
    if (widget.leg.mode == 'WALK' || _isExpanded) return _buildModeText();
    final headsign = widget.leg.headsign?.trim();
    return (headsign == null || headsign.isEmpty) ? null : headsign;
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

  String _buildModeText() {
    final modeName = getTransitModeName(widget.leg.mode);

    if (widget.leg.mode == 'WALK') {
      final distance = widget.leg.distance;
      if (distance != null && distance > 0) {
        return '$modeName (${(distance / 1000).toStringAsFixed(2)} km)';
      }
      return modeName;
    } else {
      if (widget.leg.headsign != null && widget.leg.headsign!.isNotEmpty) {
        return '$modeName • ${widget.leg.headsign}';
      }
      return modeName;
    }
  }

  Widget _buildTransitTimelineContent() {
    final stops = <_TimelineStop>[];

    stops.add(
      _TimelineStop(
        name: widget.leg.fromName,
        stopId: widget.leg.fromStopId,
        track: widget.leg.fromTrack,
        departure: widget.leg.startTime,
        scheduledDeparture: widget.leg.scheduledStartTime,
        cancelled: widget.leg.cancelled,
        isFirst: true,
        isLast: false,
      ),
    );

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
          isFirst: false,
          isLast: false,
        ),
      );
    }

    stops.add(
      _TimelineStop(
        name: widget.leg.toName,
        stopId: widget.leg.toStopId,
        track: widget.leg.toTrack,
        arrival: widget.leg.endTime,
        scheduledArrival: widget.leg.scheduledEndTime,
        cancelled: widget.leg.cancelled,
        isFirst: false,
        isLast: true,
      ),
    );

    final routeColor =
        parseHexColor(widget.leg.routeColor) ?? AppColors.accentOf(context);
    final fadedRouteColor = routeColor.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.leg.alerts.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...widget.leg.alerts.map((alert) => _buildAlertWidget(alert)),
          const SizedBox(height: 6),
        ],

        FixedTimeline.tileBuilder(
          theme: TimelineThemeData(
            nodePosition: 0,
            color: routeColor,
            indicatorTheme: const IndicatorThemeData(size: 16),
            connectorTheme: const ConnectorThemeData(thickness: 2.5),
          ),
          builder: TimelineTileBuilder.connected(
            itemCount: stops.length,
            connectionDirection: ConnectionDirection.before,
            contentsBuilder: (context, index) {
              final stop = stops[index];
              return Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 16),
                child: GestureDetector(
                  onTap: stop.stopId == null
                      ? null
                      : () => widget.openStopSheet(
                          stopId: stop.stopId,
                          stopName: stop.name,
                          referenceTime: stop.time ?? widget.leg.startTime,
                        ),
                  child: _buildStopInfo(stop),
                ),
              );
            },
            indicatorBuilder: (context, index) {
              final stop = stops[index];
              if (stop.isFirst || stop.isLast) {
                return DotIndicator(color: routeColor, size: 16);
              }
              return DotIndicator(color: fadedRouteColor, size: 12);
            },
            connectorBuilder: (context, index, connectorType) {
              return SolidLineConnector(color: fadedRouteColor);
            },
          ),
        ),

        const SizedBox(height: 12),

        _buildMetadataSection(),
      ],
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

  Widget _buildStopInfo(_TimelineStop stop) {
    final track = stop.track?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: stop.isFirst || stop.isLast
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: AppColors.black,
                ),
              ),
              if (_buildStopTimes(stop) case final times?) ...[
                const SizedBox(height: 2),
                times,
              ],
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
        ),
        // Its own column rather than a third line: the platform is a short
        // token and stacking it under the times made them compete. Nothing
        // stands in for an unknown one here — a dozen grey dashes down a
        // timeline say less than the one placeholder on the card above.
        if (track != null && track.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Track $track',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }

  /// When the service is at the stop, and when it leaves again.
  ///
  /// Where it waits, both are worth printing — the departure is the one you
  /// can still make — so they read `14:32 → 14:34`, each answering for its own
  /// delay. Where it only passes through, the single time it has is enough.
  Widget? _buildStopTimes(_TimelineStop stop) {
    final arrival = _StopTime.from(stop.arrival, stop.scheduledArrival);
    final departure = _StopTime.from(stop.departure, stop.scheduledDeparture);

    final showBoth =
        arrival != null &&
        departure != null &&
        arrival.scheduled != departure.scheduled;

    final times = showBoth
        ? [arrival, departure]
        : [if (arrival != null) arrival else if (departure != null) departure];
    if (times.isEmpty) return null;

    return Row(
      children: [
        for (final (index, time) in times.indexed) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '→',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          Text(
            formatTime(time.scheduled),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.black.withValues(alpha: 0.6),
            ),
          ),
          if (time.delay case final delay?) ...[
            const SizedBox(width: 4),
            Text(
              formatDelay(delay),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: delayColor(delay),
              ),
            ),
          ],
        ],
      ],
    );
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

  Widget _buildLegIcon() {
    return Icon(getLegIcon(widget.leg.mode), size: 24, color: AppColors.black);
  }

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
      final badge = Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg ?? const Color(0x00000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.leg.displayName!.length > 0
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

class TransferLegCard extends StatelessWidget {
  final Leg leg;
  final OpenStopSheet openStopSheet;

  /// A change is a walk between platforms; where it goes is the question.
  final VoidCallback? onShowOnMap;

  const TransferLegCard({
    super.key,
    required this.leg,
    required this.openStopSheet,
    this.onShowOnMap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onShowOnMap, child: _buildCard(context));
  }

  Widget _buildCard(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.arrowLeftRight, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transfer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const Spacer(),
              Text(
                formatDuration(leg.duration),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => openStopSheet(
              stopId: leg.fromStopId,
              stopName: leg.fromName,
              referenceTime: leg.startTime,
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.arrowRight, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${formatTime(leg.startTime)} - ${leg.fromName}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.black.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          if (leg.distance != null && leg.distance! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Approx. ${(leg.distance! / 1000).toStringAsFixed(2)} km walk',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DelayChip extends StatelessWidget {
  const _DelayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isAhead = label.startsWith('-');
    final color = isAhead ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAhead ? const Color(0xFFE8F5E9) : const Color(0xFFFFF1E0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
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
    return GestureDetector(
      onTap: () => openStopSheet(
        stopId: leg.toStopId,
        stopName: leg.toName,
        referenceTime: leg.endTime,
      ),
      child: CustomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.flag, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Finish',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const Spacer(),
                Text(
                  formatTime(arrivalTime),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStop {
  final String name;
  final String? stopId;
  final String? track;
  final bool cancelled;
  final bool isFirst;
  final bool isLast;

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
    this.isFirst = false,
    this.isLast = false,
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
