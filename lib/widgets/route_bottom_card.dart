import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/routing_options.dart';
import '../models/saved_trip.dart';
import '../models/time_selection.dart';
import '../models/transitous/server_config.dart';
import '../models/trip_history_item.dart';
import '../services/favorites_service.dart';
import '../services/transitous_geocode_service.dart';
import '../widgets/route_field_box.dart';
import '../theme/app_colors.dart';
import 'saved_trip_card.dart';
import 'buttons/pill_button.dart';
import 'buttons/primary_button.dart';
import 'search/journey_spine.dart';
import 'search/save_default_row.dart';
import 'skeletons/skeleton_shimmer.dart';

class BottomCard extends StatefulWidget {
  const BottomCard({
    super.key,
    required this.isCollapsed,
    required this.collapseProgress,
    required this.onHandleTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.fromCtrl,
    required this.toCtrl,
    required this.fromFocusNode,
    required this.toFocusNode,
    required this.showMyLocationDefault,
    required this.onUnfocus,
    required this.onSwapRequested,
    required this.options,
    required this.storedOptions,
    required this.capabilities,
    required this.onOptionsChanged,
    required this.onResetOptions,
    required this.onSaveOptionsAsDefault,
    required this.onAddViaStop,
    required this.onFromPressed,
    required this.onToPressed,
    required this.isFromFavourite,
    required this.isToFavourite,
    required this.onToggleFromFavourite,
    required this.onToggleToFavourite,
    required this.canScrollBody,
    required this.fullProgress,
    required this.routeFieldLink,
    required this.fromLoading,
    required this.toLoading,
    required this.fromSelection,
    required this.toSelection,
    required this.onSearch,
    required this.timeSelectionLayerLink,
    required this.onTimeSelectionTap,
    this.onTimeSelectionTapDown,
    this.onTimeSelectionTapCancel,
    required this.timeSelection,
    required this.recentTrips,
    required this.onRecentTripTap,
    required this.savedTrips,
    required this.onSavedTripTap,
    required this.onSeeAllSavedTrips,
    required this.favorites,
    required this.onFavoriteTap,
    required this.hasLocationPermission,
    this.tripsRefreshKey = 0,
  });

  final bool isCollapsed;
  final double collapseProgress;
  final VoidCallback onHandleTap;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final FocusNode fromFocusNode;
  final FocusNode toFocusNode;
  final bool showMyLocationDefault;
  final VoidCallback onUnfocus;
  final bool Function() onSwapRequested;

  /// The options for the next search, which last only for it.
  final RoutingOptions options;

  /// What a new search starts from, so the card can say when this one differs.
  final RoutingOptions storedOptions;

  /// Bounds the budget sliders to what the connected server will honour.
  final ServerConfig capabilities;

  final ValueChanged<RoutingOptions> onOptionsChanged;
  final VoidCallback onResetOptions;
  final VoidCallback onSaveOptionsAsDefault;
  final VoidCallback onAddViaStop;

  /// Opens the place picker for one end or the other.
  final VoidCallback onFromPressed;
  final VoidCallback onToPressed;

  final bool isFromFavourite;
  final bool isToFavourite;
  final VoidCallback onToggleFromFavourite;
  final VoidCallback onToggleToFavourite;

  /// True once the card has taken all the room it can, and so the only thing
  /// left for a drag to do is scroll.
  ///
  /// Below that a drag on the body raises the card instead, which is how a
  /// sheet is expected to behave and avoids two drag recognizers contending
  /// for the same gesture.
  final bool canScrollBody;

  /// How far past its usual stop the card has been pulled: 0 at the stop the
  /// map still shows a quarter of, 1 with only the status strip left.
  final double fullProgress;

  final LayerLink routeFieldLink;
  final bool fromLoading;
  final bool toLoading;
  final TransitousLocationSuggestion? fromSelection;
  final TransitousLocationSuggestion? toSelection;
  final ValueChanged<TimeSelection> onSearch;
  final LayerLink timeSelectionLayerLink;
  final VoidCallback onTimeSelectionTap;
  final VoidCallback? onTimeSelectionTapDown;
  final VoidCallback? onTimeSelectionTapCancel;
  final TimeSelection timeSelection;
  final List<TripHistoryItem> recentTrips;
  final ValueChanged<TripHistoryItem> onRecentTripTap;
  final List<SavedTrip> savedTrips;
  final ValueChanged<SavedTrip> onSavedTripTap;
  final VoidCallback onSeeAllSavedTrips;
  final List<FavoritePlace> favorites;
  final ValueChanged<FavoritePlace> onFavoriteTap;
  final bool hasLocationPermission;
  final int tripsRefreshKey;

  @override
  State<BottomCard> createState() => _BottomCardState();
}

class _BottomCardState extends State<BottomCard> {
  /// Holds the row open just long enough to confirm the save, since saving
  /// makes the difference it was reporting disappear.
  bool _savedAsDefault = false;
  Timer? _savedTimer;

  @override
  void initState() {
    super.initState();
    // Focus decides whether the stages or the suggestions get the room, so
    // it has to reach build rather than only the tap handlers.
    widget.fromFocusNode.addListener(_onFocusChanged);
    widget.toFocusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant BottomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fromFocusNode != widget.fromFocusNode) {
      oldWidget.fromFocusNode.removeListener(_onFocusChanged);
      widget.fromFocusNode.addListener(_onFocusChanged);
    }
    if (oldWidget.toFocusNode != widget.toFocusNode) {
      oldWidget.toFocusNode.removeListener(_onFocusChanged);
      widget.toFocusNode.addListener(_onFocusChanged);
    }
    // A further edit is a new difference from the stored defaults, so the
    // confirmation stops applying to it.
    if (oldWidget.options != widget.options) {
      _savedTimer?.cancel();
      _savedAsDefault = false;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _savedTimer?.cancel();
    widget.fromFocusNode.removeListener(_onFocusChanged);
    widget.toFocusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  final ScrollController _scroll = ScrollController();

  /// True while a downward drag at the top of the list is lowering the card
  /// rather than scrolling, so the release knows to snap.
  bool _pullingDown = false;

  /// At the top of the list, a downward drag has nothing left to scroll, so
  /// it hands the card back down instead of dead-ending in an overscroll.
  bool _onScrollNotification(ScrollNotification notification) {
    if (!widget.canScrollBody) return false;
    if (notification is OverscrollNotification && notification.overscroll < 0) {
      if (!_pullingDown) {
        _pullingDown = true;
        widget.onDragStart();
      }
      widget.onDragUpdate(-notification.overscroll);
      return true;
    }
    if (notification is ScrollEndNotification && _pullingDown) {
      _pullingDown = false;
      widget.onDragEnd(0);
    }
    return false;
  }

  /// The journey stages. Collapsed, the card is just a search box.
  Widget? _buildSpine() {
    if (widget.isCollapsed) return null;
    return JourneySpine(
      options: widget.options,
      capabilities: widget.capabilities,
      onChanged: widget.onOptionsChanged,
      onAddViaStop: widget.onAddViaStop,
    );
  }

  /// Everything between the handle and the action bar, as one scroll.
  ///
  /// The fields, the journey stages and the trip lists share a single
  /// scrollable so that expanding a stage pushes the rest down rather than
  /// stranding it: collapsing a section to reach the one below it is the
  /// wrong way round.
  Widget _buildScrollableBody(
    BuildContext context, {
    required List<Widget> above,
    required List<Widget> below,
  }) {
    final Widget scroller = NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: widget.canScrollBody
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...above,
            if (!widget.isCollapsed) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: below,
                ),
              ),
              // Clears the pinned action bar's shadow.
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );

    if (widget.canScrollBody) return scroller;

    // Not yet at the top stop, so a drag on the body raises the card. The
    // recognizer is only installed in that state, which keeps it out of the
    // arena once the list is the thing that should be moving.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) => widget.onDragStart(),
      onVerticalDragUpdate: (d) => widget.onDragUpdate(d.delta.dy),
      onVerticalDragEnd: (d) => widget.onDragEnd(d.velocity.pixelsPerSecond.dy),
      child: scroller,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The rounded top is what makes the card read as sitting over the map.
    // Once there is no map left beside it, the curve has nothing to sit over.
    final radius = 16.0 * (1 - widget.fullProgress);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The app asks for light status-bar icons against the map. Against a
      // white card at the top of the screen they would be invisible.
      value: widget.fullProgress > 0.5
          ? SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: const Color(0x00000000),
            )
          : SystemUiOverlayStyle.light.copyWith(
              statusBarColor: const Color(0x00000000),
            ),
      child: _buildCard(context, radius),
    );
  }

  Widget _buildCard(BuildContext context, double radius) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 14,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (widget.fromFocusNode.hasFocus || widget.toFocusNode.hasFocus) {
            return;
          }
          widget.onUnfocus();
        },
        child: Listener(
          onPointerDown: (_) {
            if (widget.fromFocusNode.hasFocus || widget.toFocusNode.hasFocus) {
              return;
            }
            widget.onUnfocus();
          },
          child: SafeArea(
            // Honoured only once the card actually reaches the strip, so the
            // handle does not sit under the clock.
            top: widget.fullProgress > 0.5,
            child: SizedBox.expand(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onHandleTap,
                    onVerticalDragStart: (_) => widget.onDragStart(),
                    onVerticalDragUpdate: (d) =>
                        widget.onDragUpdate(d.delta.dy),
                    onVerticalDragEnd: (d) =>
                        widget.onDragEnd(d.velocity.pixelsPerSecond.dy),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 18),
                        Container(
                          width: 48,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),

                  Expanded(
                    child: _buildScrollableBody(
                      context,
                      above: [
                        Builder(
                          builder: (context) {
                            final fadeStart = 0.5;
                            final t =
                                ((widget.collapseProgress - fadeStart) /
                                        (1 - fadeStart))
                                    .clamp(0.0, 1.0);
                            final opacity = 1.0 - Curves.easeOut.transform(t);
                            return GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: widget.onUnfocus,
                              child: ClipRect(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  heightFactor: opacity,
                                  child: Opacity(
                                    opacity: opacity,
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        8,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Where to?',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Listener(
                            onPointerDown: (_) {},
                            behavior: HitTestBehavior.opaque,
                            child: GestureDetector(
                              onTap: () {},
                              behavior: HitTestBehavior.opaque,
                              child: RouteFieldBox(
                                fromController: widget.fromCtrl,
                                toController: widget.toCtrl,
                                fromFocusNode: widget.fromFocusNode,
                                toFocusNode: widget.toFocusNode,
                                showMyLocationDefault:
                                    widget.showMyLocationDefault,
                                accentColor: AppColors.accentOf(context),
                                onSwapRequested: widget.onSwapRequested,
                                layerLink: widget.routeFieldLink,
                                fromLoading: widget.fromLoading,
                                toLoading: widget.toLoading,
                                middle: _buildSpine(),
                                onFromPressed: widget.onFromPressed,
                                onToPressed: widget.onToPressed,
                                isFromFavourite: widget.isFromFavourite,
                                isToFavourite: widget.isToFavourite,
                                onToggleFromFavourite:
                                    widget.onToggleFromFavourite,
                                onToggleToFavourite: widget.onToggleToFavourite,
                              ),
                            ),
                          ),
                        ),

                        // Always offered, not only once something differs:
                        // the row is where the routing options are managed
                        // from, and hunting for a button that appears and
                        // disappears is worse than one that is simply there.
                        if (!widget.isCollapsed)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: SaveDefaultRow(
                              saved: _savedAsDefault,
                              differsFromStored:
                                  widget.options != widget.storedOptions,
                              onReset: widget.onResetOptions,
                              onSaveAsDefault: () {
                                widget.onSaveOptionsAsDefault();
                                setState(() => _savedAsDefault = true);
                                _savedTimer?.cancel();
                                _savedTimer = Timer(
                                  const Duration(milliseconds: 1800),
                                  () {
                                    if (mounted) {
                                      setState(() => _savedAsDefault = false);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                      below: [
                        if (widget.savedTrips.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: widget.onUnfocus,
                              child: _SavedTripsSection(
                                savedTrips: widget.savedTrips,
                                onSavedTripTap: widget.onSavedTripTap,
                                onSeeAll: widget.onSeeAllSavedTrips,
                              ),
                            ),
                          ),
                        if (widget.recentTrips.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: widget.onUnfocus,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recent trips',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...widget.recentTrips.map(
                                    (trip) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: _RecentTripTile(
                                        trip: trip,
                                        onTap: () =>
                                            widget.onRecentTripTap(trip),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 96),
                      ],
                    ),
                  ),

                  if (!widget.isCollapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Builder(
                        builder: (context) {
                          const double start = 0.5;
                          final double raw =
                              (widget.collapseProgress - start) / (1 - start);
                          final double t = raw.clamp(0.0, 1.0);
                          final double dy = 16.0 * t;
                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: widget.onUnfocus,
                            child: Transform.translate(
                              offset: Offset(0, dy),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {},
                                    behavior: HitTestBehavior.opaque,
                                    child: CompositedTransformTarget(
                                      link: widget.timeSelectionLayerLink,
                                      child: PillButton(
                                        onTap: widget.onTimeSelectionTap,
                                        onTapDown:
                                            widget.onTimeSelectionTapDown,
                                        onTapCancel:
                                            widget.onTimeSelectionTapCancel,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.clock,
                                              size: 16,
                                              color: AppColors.black,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              widget.timeSelection
                                                  .toDisplayString(),
                                              style: TextStyle(
                                                color: AppColors.black,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () {},
                                    behavior: HitTestBehavior.opaque,
                                    child: PrimaryButton(
                                      onTap: () =>
                                          widget.onSearch(widget.timeSelection),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            'Search',
                                            style: TextStyle(
                                              color: AppColors.solidWhite,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The next few kept connections, shown above Recent trips because a trip
/// the user chose to keep outranks one they merely searched for.
///
/// Deliberately capped: this is a shortcut on the way to searching, not the
/// full list, which lives one tap away behind "See all".
class _SavedTripsSection extends StatelessWidget {
  const _SavedTripsSection({
    required this.savedTrips,
    required this.onSavedTripTap,
    required this.onSeeAll,
  });

  static const int _maxShown = 3;

  final List<SavedTrip> savedTrips;
  final ValueChanged<SavedTrip> onSavedTripTap;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    // Anything already finished belongs in the history on the full screen,
    // not in the way of planning the next journey.
    final upcoming = savedTrips.where((trip) => !trip.isPast).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final shown = upcoming.take(_maxShown).toList();
    final hiddenCount = upcoming.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Saved trips',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSeeAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hiddenCount > 0 ? 'See all ($hiddenCount more)' : 'See all',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.accentOf(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final trip in shown)
          SavedTripCard(
            trip: trip,
            margin: const EdgeInsets.symmetric(vertical: 4),
            onTap: () => onSavedTripTap(trip),
          ),
      ],
    );
  }
}

class _RecentTripTile extends StatefulWidget {
  const _RecentTripTile({required this.trip, required this.onTap});

  final TripHistoryItem trip;
  final VoidCallback onTap;

  @override
  State<_RecentTripTile> createState() => _RecentTripTileState();
}

class _RecentTripTileState extends State<_RecentTripTile> {
  bool _isLoading = false;

  void _handleTap() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    widget.onTap();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.black.withValues(alpha: 0.07)),
          ),
          alignment: Alignment.center,
          child: Icon(LucideIcons.route, size: 18, color: AppColors.black),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.trip.fromName,
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.trip.toName,
                      style: TextStyle(
                        color: AppColors.black.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: _isLoading ? SkeletonShimmer(child: content) : content,
    );
  }
}
