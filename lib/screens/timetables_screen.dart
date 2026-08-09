import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../models/time_selection.dart';
import '../models/saved_place.dart';
import '../models/stop_time.dart';
import '../screens/connection_info_screen.dart';
import '../services/location_service.dart';
import '../services/favorites_service.dart';
import '../services/saved_places_service.dart';
import '../services/stop_times_service.dart';
import '../screens/location_search_screen.dart';
import '../services/transitous_geocode_service.dart';
import '../utils/color_utils.dart';
import '../utils/custom_page_route.dart';
import '../utils/haptics.dart';
import '../utils/favorite_icons.dart';
import '../utils/leg_helper.dart' show getLegIcon;
import '../utils/stop_time_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/buttons/pill_button.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeletons/skeleton_list.dart';
import '../widgets/load_more_button.dart';
import '../widgets/time_selection_overlay.dart';
import '../widgets/validation_toast.dart';

class TimetablesScreen extends StatefulWidget {
  const TimetablesScreen({super.key, this.initialStop});

  final TransitousLocationSuggestion? initialStop;

  @override
  State<TimetablesScreen> createState() => _TimetablesScreenState();
}

class _TimetablesScreenState extends State<TimetablesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final LayerLink _searchFieldLink = LayerLink();
  final LayerLink _timeSelectionLayerLink = LayerLink();

  TimeSelection _timeSelection = TimeSelection.now();
  bool _showTimeSelectionOverlay = false;
  bool _suppressTimeSelectionReopen = false;
  List<SavedPlace> _savedTimetablePlaces = [];
  List<FavoritePlace> _favourites = FavoritesService.favoritesListenable.value;
  LatLng? _lastUserLatLng;
  TransitousLocationSuggestion? _selectedStop;
  List<StopTime>? _stopTimes;
  int _centerIndex = 0;
  bool _isLoadingStopTimes = false;
  String? _nextPageCursor;
  bool _isLoadingMore = false;
  String? _previousPageCursor;
  bool _isLoadingPrevious = false;
  late final ScrollController _resultsScrollController;
  bool _appliedInitialPreviousOffset = false;
  static const double _seePreviousScrollOffset = 40.0;
  static const Key _centerKey = ValueKey('stop-times-center');

  bool get _hasPreviousPage => _previousPageCursor?.isNotEmpty ?? false;
  bool get _hasNextPage => _nextPageCursor?.isNotEmpty ?? false;
  DateTime? get _startTimeParam =>
      _timeSelection.isNow ? null : _timeSelection.dateTime;

  String? _normalizeCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return null;
    return cursor;
  }

  @override
  void initState() {
    super.initState();
    _resultsScrollController = ScrollController();
    _searchController.addListener(_onSearchTextChanged);
    _searchFocus.addListener(_onFocusChanged);
    _checkLocationPermission();
    unawaited(_loadSavedTimetablePlaces());
    FavoritesService.favoritesListenable.addListener(_onFavouritesChanged);
    unawaited(FavoritesService.getFavorites());
    _applyInitialStop(widget.initialStop);
  }

  @override
  void didUpdateWidget(covariant TimetablesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStop?.id != oldWidget.initialStop?.id) {
      _applyInitialStop(widget.initialStop);
    }
  }

  @override
  void dispose() {
    FavoritesService.favoritesListenable.removeListener(_onFavouritesChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final granted = await LocationService.ensurePermission();
    if (!mounted) return;

    if (granted) {
      try {
        final pos = await LocationService.currentPosition();
        if (mounted) {
          setState(() {
            _lastUserLatLng = LatLng(pos.latitude, pos.longitude);
          });
        }
      } catch (_) {}
    }
  }

  /// What to show before a stop is chosen.
  ///
  /// The stops you use and the ones you keep, rather than an empty screen
  /// telling you to type — choosing a stop is what this screen is for, and
  /// both lists already exist.
  Widget _buildStartingPoint(BuildContext context) {
    final recents = _savedTimetablePlaces
        .where((place) => place.type.toUpperCase() == 'STOP')
        .take(6)
        .toList();
    final favourites = _favourites.where((f) => f.isStation).toList();

    if (recents.isEmpty && favourites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EmptyState(
                icon: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    LucideIcons.trainFront,
                    size: 40,
                    color: AppColors.black.withValues(alpha: 0.2),
                  ),
                ),
                title: 'Search for a stop',
                subtitle:
                    'Enter a stop name above to view\ndepartures and arrivals',
                titleStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
                subtitleStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.black.withValues(alpha: 0.4),
                  height: 1.4,
                ),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      children: [
        // Only when some favourite actually is a station; a list of places
        // this screen cannot open would be a list of dead ends.
        if (favourites.isNotEmpty) ...[
          _stationHeading('Favourite stops'),
          for (final favourite in favourites)
            _StationRow(
              icon: iconForFavorite(favourite.iconName),
              title: favourite.displayName,
              subtitle: favourite.hasAlias ? favourite.name : null,
              onTap: () => unawaited(_openStationByName(favourite.name)),
            ),
          const SizedBox(height: 20),
        ],
        if (recents.isNotEmpty) ...[
          _stationHeading('Recent stops'),
          for (final place in recents)
            _StationRow(
              icon: LucideIcons.busFront,
              title: place.name,
              subtitle: place.city,
              onTap: () => unawaited(_openStationByName(place.name)),
            ),
        ],
      ],
    );
  }

  Widget _stationHeading(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: AppColors.black.withValues(alpha: 0.45),
      ),
    ),
  );

  /// Opens a stop the app remembers by name.
  ///
  /// Neither a saved place nor a favourite stores the feed's stop id — both
  /// would mint a synthetic one, and the departures endpoint would be handed
  /// a string that is not a stop. Resolving the name is what gets a real id.
  Future<void> _openStationByName(String name) async {
    Haptics.lightTick();
    _searchController.text = name;
    final resolved = await _resolveStopFromQuery(name);
    if (!mounted || resolved == null) return;
    await _onSearch();
  }

  void _onFavouritesChanged() {
    if (!mounted) return;
    setState(() => _favourites = FavoritesService.favoritesListenable.value);
  }

  Future<void> _loadSavedTimetablePlaces() async {
    final places = await SavedPlacesService.loadPlaces(
      bucket: SavedPlacesBucket.timetable,
    );
    if (!mounted) return;
    setState(() {
      _savedTimetablePlaces = places;
    });
  }

  Future<void> _recordSavedPlace(
    TransitousLocationSuggestion suggestion,
  ) async {
    final name = suggestion.name.trim();
    if (name.isEmpty) return;
    final selected = SavedPlace(
      name: name,
      type: suggestion.type,
      lat: suggestion.lat,
      lon: suggestion.lon,
      importance: SavedPlace.defaultImportance,
      city: suggestion.defaultArea,
      countryCode: suggestion.country,
    );
    final updated = SavedPlacesService.applySelection(
      _savedTimetablePlaces,
      selected,
    );
    if (!mounted) return;
    setState(() {
      _savedTimetablePlaces = updated;
    });
    unawaited(
      SavedPlacesService.savePlaces(
        bucket: SavedPlacesBucket.timetable,
        places: updated,
      ),
    );
  }

  void _onFocusChanged() {
    setState(() {});
    if (_searchFocus.hasFocus) {
      _onSearchTextChanged();
    }
  }

  void _onTimeSelectionChanged(TimeSelection newSelection) {
    setState(() {
      _timeSelection = newSelection;
    });
  }

  void _toggleTimeSelectionOverlay() {
    if (_showTimeSelectionOverlay) {
      _closeTimeSelectionOverlay();
    } else {
      _openTimeSelectionOverlay();
    }
  }

  void _openTimeSelectionOverlay() {
    if (_showTimeSelectionOverlay) return;
    _searchFocus.unfocus();
    setState(() {
      _showTimeSelectionOverlay = true;
    });
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Time selection',
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return TimeSelectionOverlay(
          currentSelection: _timeSelection,
          onSelectionChanged: _onTimeSelectionChanged,
          onDismiss: _closeTimeSelectionOverlay,
          showDepartArriveToggle: false,
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ).then((_) {
      if (!mounted) return;
      if (_showTimeSelectionOverlay) {
        setState(() => _showTimeSelectionOverlay = false);
      }
    });
  }

  void _closeTimeSelectionOverlay() {
    if (!_showTimeSelectionOverlay) return;
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  void _handleTimeButtonTapDown() {
    if (_showTimeSelectionOverlay) {
      _suppressTimeSelectionReopen = true;
      _closeTimeSelectionOverlay();
    }
  }

  void _handleTimeButtonTapCancel() {
    _suppressTimeSelectionReopen = false;
  }

  void _handleTimeButtonTap() {
    if (_suppressTimeSelectionReopen) {
      _suppressTimeSelectionReopen = false;
      return;
    }
    _toggleTimeSelectionOverlay();
  }

  void _onSearchTextChanged() => setState(() {});

  void _applyInitialStop(TransitousLocationSuggestion? initialStop) {
    if (initialStop == null) return;
    _selectedStop = initialStop;
    _searchController.text = initialStop.name;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onSearch();
    });
  }

  /// Opens the full-screen picker, restricted to stops.
  ///
  /// Same screen the route fields use, so favourites and recent stops show
  /// here too — they never did in the dropdown this replaces.
  Future<void> _openStopSearch() async {
    _searchFocus.unfocus();
    final picked = await Navigator.of(context)
        .push<TransitousLocationSuggestion>(
          CustomPageRoute(
            child: LocationSearchScreen(
              title: 'Stop',
              bucket: SavedPlacesBucket.timetable,
              initialQuery: _searchController.text,
              type: 'STOP',
            ),
          ),
        );
    if (!mounted || picked == null) return;
    _onSuggestionSelected(picked);
  }

  void _onSuggestionSelected(TransitousLocationSuggestion suggestion) {
    unawaited(_recordSavedPlace(suggestion));
    setState(() {
      _searchController.text = suggestion.name;
      _selectedStop = suggestion;
      _searchFocus.unfocus();
    });
  }

  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      showValidationToast(context, 'Please enter a stop name');
      return;
    }

    var selectedStop = _selectedStop;
    if (selectedStop?.id == null && query.length >= 3) {
      selectedStop = await _resolveStopFromQuery(query);
    }

    final stopId = selectedStop?.id;
    if (stopId == null) {
      showValidationToast(context, 'Please select a stop from the list');
      return;
    }

    _searchFocus.unfocus();

    setState(() {
      _isLoadingStopTimes = true;
      _stopTimes = null;
      _nextPageCursor = null;
      _previousPageCursor = null;
      _isLoadingMore = false;
      _isLoadingPrevious = false;
      _appliedInitialPreviousOffset = false;
    });
    if (_resultsScrollController.hasClients) {
      _resultsScrollController.jumpTo(0);
    }

    try {
      final response = await StopTimesService.fetchStopTimes(
        stopId: stopId,
        n: 20,
        startTime: _startTimeParam,
        arriveBy: _timeSelection.isArriveBy,
      );

      if (!mounted) return;

      setState(() {
        _stopTimes = deduplicateStopTimes(response.stopTimes);
        _centerIndex = 0;
        _nextPageCursor = _normalizeCursor(response.nextPageCursor);
        _previousPageCursor = _normalizeCursor(response.previousPageCursor);
        _isLoadingStopTimes = false;
      });
      _maybeApplyInitialPreviousOffset();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingStopTimes = false;
        _previousPageCursor = null;
        _isLoadingPrevious = false;
      });

      showValidationToast(context, 'Failed to load stop times');
    }
  }

  Future<TransitousLocationSuggestion?> _resolveStopFromQuery(
    String query,
  ) async {
    if (query.trim().length < 3) return null;
    try {
      final results = await TransitousGeocodeService.fetchSuggestions(
        text: query,
        type: 'STOP',
        placeBias: _lastUserLatLng,
      );
      if (results.isEmpty) return null;
      final suggestion = results.first;
      if (!mounted) return suggestion;
      unawaited(_recordSavedPlace(suggestion));
      setState(() {
        _searchController.text = suggestion.name;
        _selectedStop = suggestion;
        _searchFocus.unfocus();
      });
      return suggestion;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore ||
        _nextPageCursor == null ||
        _selectedStop?.id == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await StopTimesService.fetchStopTimes(
        stopId: _selectedStop?.id ?? '',
        n: 25,
        pageCursor: _nextPageCursor,
        startTime: _startTimeParam,
        arriveBy: _timeSelection.isArriveBy,
      );

      if (!mounted) return;

      setState(() {
        _stopTimes = deduplicateStopTimes([
          ...?_stopTimes,
          ...response.stopTimes,
        ]);
        _nextPageCursor = _normalizeCursor(response.nextPageCursor);
        _previousPageCursor = _normalizeCursor(
          response.previousPageCursor ?? _previousPageCursor,
        );
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
      });

      showValidationToast(context, 'Failed to load more stop times');
    }
  }

  Future<void> _loadPrevious() async {
    if (_isLoadingPrevious || !_hasPreviousPage || _selectedStop?.id == null) {
      return;
    }

    setState(() {
      _isLoadingPrevious = true;
    });

    try {
      final response = await StopTimesService.fetchStopTimes(
        stopId: _selectedStop?.id ?? '',
        n: 25,
        pageCursor: _previousPageCursor,
        startTime: _startTimeParam,
        arriveBy: _timeSelection.isArriveBy,
      );

      if (!mounted) return;

      final oldLength = _stopTimes?.length ?? 0;
      final combined = deduplicateStopTimes([
        ...response.stopTimes,
        ...?_stopTimes,
      ]);
      final addedCount = combined.length - oldLength;

      setState(() {
        _stopTimes = combined;
        _centerIndex += addedCount;
        _previousPageCursor = _normalizeCursor(response.previousPageCursor);
        _isLoadingPrevious = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingPrevious = false;
      });

      showValidationToast(context, 'Failed to load previous stop times');
    }
  }

  void _maybeApplyInitialPreviousOffset() {
    if (_appliedInitialPreviousOffset) return;
    if (!_hasPreviousPage) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_resultsScrollController.hasClients) return;
      final minExtent = _resultsScrollController.position.minScrollExtent;
      _resultsScrollController.jumpTo(minExtent + _seePreviousScrollOffset);
      _appliedInitialPreviousOffset = true;
    });
  }

  Widget _buildLoadingSkeleton() {
    return const SkeletonList(
      itemCount: 8,
      itemHeight: 80,
      listPadding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 96),
      itemMargin: EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.all(Radius.circular(14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();

    return PopScope(
      canPop: !_searchFocus.hasFocus && !_showTimeSelectionOverlay,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_showTimeSelectionOverlay) {
            _closeTimeSelectionOverlay();
          } else if (_searchFocus.hasFocus) {
            _searchFocus.unfocus();
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          _searchFocus.unfocus();
        },
        child: Container(
          color: AppColors.white,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.accentOf(
                                    context,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  LucideIcons.clock,
                                  size: 24,
                                  color: AppColors.accentOf(context),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Flexible, or the title and its subtitle claim
                              // their natural width and overflow the row on a
                              // narrow screen.
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Timetables',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.black,
                                        height: 1.1,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Stop departures & arrivals',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.black.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          CompositedTransformTarget(
                            link: _searchFieldLink,
                            child: GestureDetector(
                              onTap: () {},
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.black.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.search,
                                      size: 20,
                                      color: AppColors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CupertinoTextField(
                                        controller: _searchController,
                                        focusNode: _searchFocus,
                                        // Opens the picker rather than
                                        // typing here: favourites and recents
                                        // need more room than a dropdown.
                                        readOnly: true,
                                        showCursor: false,
                                        onTap: () =>
                                            unawaited(_openStopSearch()),
                                        placeholder: 'Search for a stop...',
                                        placeholderStyle: TextStyle(
                                          color: AppColors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          fontSize: 16,
                                        ),
                                        style: TextStyle(
                                          color: AppColors.black,
                                          fontSize: 16,
                                        ),
                                        decoration: null,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        cursorColor: AppColors.accentOf(
                                          context,
                                        ),
                                        maxLines: 1,
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: (_) => _onSearch(),
                                      ),
                                    ),
                                    if (_searchController.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          child: Icon(
                                            LucideIcons.x,
                                            size: 20,
                                            color: AppColors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              CompositedTransformTarget(
                                link: _timeSelectionLayerLink,
                                child: PillButton(
                                  onTapDown: _handleTimeButtonTapDown,
                                  onTapCancel: _handleTimeButtonTapCancel,
                                  onTap: _handleTimeButtonTap,
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
                                        _timeSelection.toDisplayString(),
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
                              const Spacer(),
                              PrimaryButton(
                                onTap: _onSearch,
                                child: const Text(
                                  'Search',
                                  style: TextStyle(
                                    color: AppColors.solidWhite,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: _isLoadingStopTimes
                          ? _buildLoadingSkeleton()
                          : _stopTimes != null
                          ? Builder(
                              builder: (context) {
                                final hasPreviousSlot = _hasPreviousPage;
                                final hasNextSlot = _hasNextPage;
                                final beforeItems = _stopTimes!.sublist(
                                  0,
                                  _centerIndex,
                                );
                                final afterItems = _stopTimes!.sublist(
                                  _centerIndex,
                                );
                                final beforeCount =
                                    beforeItems.length +
                                    (hasPreviousSlot ? 1 : 0);
                                final afterCount =
                                    afterItems.length + (hasNextSlot ? 1 : 0);

                                Widget buildStopTimeTile(StopTime stopTime) {
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        CustomPageRoute(
                                          child: ConnectionInfoScreen(
                                            tripId: stopTime.tripId,
                                          ),
                                        ),
                                      );
                                    },
                                    child: _StopTimeCard(stopTime: stopTime),
                                  );
                                }

                                return CustomScrollView(
                                  controller: _resultsScrollController,
                                  center: _centerKey,
                                  slivers: [
                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      // Within a reverse-growth sliver,
                                      // delegate index 0 is adjacent to the
                                      // center anchor, so items are listed
                                      // nearest-first with the "See previous"
                                      // button last (farthest away, requiring
                                      // a scroll up to reach it).
                                      sliver: SliverList(
                                        delegate: SliverChildBuilderDelegate((
                                          context,
                                          index,
                                        ) {
                                          if (index < beforeItems.length) {
                                            final stopTime =
                                                beforeItems[beforeItems.length -
                                                    1 -
                                                    index];
                                            return buildStopTimeTile(stopTime);
                                          }
                                          return LoadMoreButton(
                                            onTap: _loadPrevious,
                                            isLoading: _isLoadingPrevious,
                                            label: 'See previous',
                                            icon: LucideIcons.chevronUp,
                                          );
                                        }, childCount: beforeCount),
                                      ),
                                    ),
                                    SliverPadding(
                                      key: _centerKey,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      sliver: SliverList(
                                        delegate: SliverChildBuilderDelegate((
                                          context,
                                          index,
                                        ) {
                                          if (index < afterItems.length) {
                                            return buildStopTimeTile(
                                              afterItems[index],
                                            );
                                          }
                                          if (hasNextSlot &&
                                              index == afterItems.length) {
                                            return LoadMoreButton(
                                              onTap: _loadMore,
                                              isLoading: _isLoadingMore,
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        }, childCount: afterCount),
                                      ),
                                    ),
                                    const SliverToBoxAdapter(
                                      child: SizedBox(height: 96),
                                    ),
                                  ],
                                );
                              },
                            )
                          : _buildStartingPoint(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StopTimeCard extends StatelessWidget {
  const _StopTimeCard({required this.stopTime});

  final StopTime stopTime;

  @override
  Widget build(BuildContext context) {
    final routeColor = parseHexColorOrAccent(context, stopTime.routeColor);
    final routeTextColor =
        parseHexColor(stopTime.routeTextColor) ?? AppColors.solidWhite;

    final modeIcon = getLegIcon(stopTime.mode);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.black.withValues(alpha: 0.1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              modeIcon,
              size: 24,
              color: AppColors.black.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 30),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: routeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stopTime.displayName,
                      style: TextStyle(
                        color: routeTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stopTime.headsign,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeWithDelayText(
                  label: 'Arr',
                  scheduled: stopTime.place.scheduledArrival,
                  actual: stopTime.place.arrival,
                ),
                const SizedBox(height: 4),
                _TimeWithDelayText(
                  label: 'Dep',
                  scheduled: stopTime.place.scheduledDeparture,
                  actual: stopTime.place.departure,
                  subdued: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeWithDelayText extends StatelessWidget {
  const _TimeWithDelayText({
    required this.label,
    required this.scheduled,
    required this.actual,
    this.subdued = false,
  });

  final String label;
  final DateTime? scheduled;
  final DateTime? actual;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final display = formatTime(scheduled ?? actual, nullPlaceholder: '--:--');
    final delay = (scheduled != null && actual != null)
        ? computeDelay(scheduled!, actual!)
        : null;
    final baseColor = subdued
        ? AppColors.black.withValues(alpha: 0.6)
        : AppColors.black;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label $display',
          style: TextStyle(
            fontSize: 14,
            fontWeight: subdued ? FontWeight.w500 : FontWeight.w600,
            color: baseColor,
          ),
        ),
        if (delay != null) ...[
          const SizedBox(width: 6),
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
    );
  }
}

/// One remembered stop, offered before anything has been searched for.
class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.black.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
