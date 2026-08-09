import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/saved_place.dart';
import '../services/favorites_service.dart';
import '../services/saved_places_service.dart';
import '../services/transitous_geocode_service.dart';
import '../theme/app_colors.dart';
import '../utils/custom_page_route.dart';
import '../utils/favorite_icons.dart';
import '../utils/haptics.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/edit_favorite_overlay.dart';
import 'favourites_map_screen.dart';

/// What the app calls the rider's current position.
///
/// The origin field leaves itself empty for this and resolves the position at
/// search time, so the trip is planned from where you are when you press
/// Search rather than where you were when you picked.
const String myLocationName = 'My Location';

/// The answer the picker returns for it — recognised by id, so a place that
/// happens to share the name is not mistaken for it.
final TransitousLocationSuggestion myLocationSuggestion =
    TransitousLocationSuggestion(
      id: 'my-location',
      name: myLocationName,
      lat: 0,
      lon: 0,
      type: 'PLACE',
    );

/// Picks a place, full screen.
///
/// A screen rather than a dropdown under the field: the list has favourites,
/// recent places and geocoder results to show, and an overlay capped at a few
/// hundred pixels has to fight the card it hangs from for the room.
class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({
    super.key,
    required this.title,
    required this.bucket,
    this.initialQuery = '',
    this.placeBias,
    this.type,
    this.showFavourites = true,
    this.showMyLocation = false,
  });

  /// Names what is being picked: "Origin", "Destination", "Stop".
  final String title;

  /// Which recents to learn from and offer.
  final SavedPlacesBucket bucket;

  final String initialQuery;

  /// Biases the geocoder towards where the rider is.
  final LatLng? placeBias;

  /// Restricts results, e.g. `STOP` for a timetable search.
  final String? type;

  final bool showFavourites;

  /// Offers where the rider is standing as the first answer.
  ///
  /// Only for a route endpoint: a coordinate is not a stop, so a timetable
  /// search has nothing to do with one. The caller passes this rather than
  /// the screen asking, because the caller already knows whether location is
  /// permitted — offering a row that cannot answer would be worse than not
  /// offering it.
  final bool showMyLocation;

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );
  final FocusNode _focus = FocusNode();

  List<TransitousLocationSuggestion> _suggestions = const [];
  List<SavedPlace> _recents = const [];
  List<FavoritePlace> _favourites = const [];
  bool _isFetching = false;
  Timer? _debounce;

  /// Guards against an earlier, slower search overwriting a later one.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _favourites = FavoritesService.favoritesListenable.value;
    FavoritesService.favoritesListenable.addListener(_onFavouritesChanged);
    unawaited(FavoritesService.getFavorites());
    unawaited(_loadRecents());
    _controller.addListener(_onQueryChanged);
    // The keyboard is why this screen opened; waiting for a second tap on the
    // field it already put focus on would be a step for nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    FavoritesService.favoritesListenable.removeListener(_onFavouritesChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFavouritesChanged() {
    if (!mounted) return;
    setState(() => _favourites = FavoritesService.favoritesListenable.value);
  }

  Future<void> _loadRecents() async {
    final places = await SavedPlacesService.loadPlaces(bucket: widget.bucket);
    if (!mounted) return;
    setState(() => _recents = places);
  }

  String get _query => _controller.text.trim();

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _query;

    // A pasted coordinate is already an answer; there is nothing to look up.
    final coord = TransitousGeocodeService.tryParseLatLon(query);
    if (coord != null) {
      ++_requestId;
      setState(() {
        _suggestions = [TransitousLocationSuggestion.fromLatLon(coord)];
        _isFetching = false;
      });
      return;
    }

    if (query.length < 3) {
      ++_requestId;
      setState(() {
        _suggestions = const [];
        _isFetching = false;
      });
      return;
    }

    setState(() => _isFetching = true);
    _debounce = Timer(const Duration(milliseconds: 220), () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    try {
      final results = await TransitousGeocodeService.fetchSuggestions(
        text: query,
        placeBias: widget.placeBias,
        type: widget.type,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = _prioritiseRecents(results);
        _isFetching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = const [];
        _isFetching = false;
      });
    }
  }

  /// Hoists places this rider has picked before, most-used first.
  ///
  /// The geocoder ranks by its own idea of importance, which cannot know that
  /// you go to one of two identically named stops every day.
  List<TransitousLocationSuggestion> _prioritiseRecents(
    List<TransitousLocationSuggestion> results,
  ) {
    if (_recents.isEmpty) return results;
    final importanceByKey = {
      for (final place in _recents) place.key: place.importance,
    };
    final originalIndex = {
      for (var i = 0; i < results.length; i++) results[i]: i,
    };
    return [...results]..sort((a, b) {
      final aImportance =
          importanceByKey[SavedPlace.buildKey(
            type: a.type,
            lat: a.lat,
            lon: a.lon,
          )];
      final bImportance =
          importanceByKey[SavedPlace.buildKey(
            type: b.type,
            lat: b.lat,
            lon: b.lon,
          )];
      if ((aImportance != null) != (bImportance != null)) {
        return aImportance != null ? -1 : 1;
      }
      if (aImportance != null && bImportance != null) {
        final diff = bImportance.compareTo(aImportance);
        if (diff != 0) return diff;
      }
      return originalIndex[a]!.compareTo(originalIndex[b]!);
    });
  }

  void _pick(TransitousLocationSuggestion suggestion) {
    Haptics.lightTick();
    // Where you are is not a place you searched for, so it does not belong
    // in the list of places you did.
    if (suggestion.id == myLocationSuggestion.id) {
      Navigator.of(context).pop(suggestion);
      return;
    }
    unawaited(
      SavedPlacesService.savePlaces(
        bucket: widget.bucket,
        places: SavedPlacesService.applySelection(
          _recents,
          SavedPlace(
            name: suggestion.name,
            type: suggestion.type,
            lat: suggestion.lat,
            lon: suggestion.lon,
            importance: SavedPlacesService.initialImportance,
            city: suggestion.defaultArea,
            countryCode: suggestion.country,
          ),
        ),
      ),
    );
    Navigator.of(context).pop(suggestion);
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<FavoritePlace>(
      CustomPageRoute(
        child: const AddFavouriteMapScreen(saveAsFavourite: false),
      ),
    );
    if (!mounted || picked == null) return;
    _pick(
      TransitousLocationSuggestion(
        id: 'map-${picked.lat}-${picked.lon}',
        name: picked.name,
        lat: picked.lat,
        lon: picked.lon,
        type: 'PLACE',
      ),
    );
  }

  Future<void> _editFavourite(FavoritePlace favourite) async {
    Haptics.lightTick();
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => EditFavoriteOverlay(
        favorite: favourite,
        onSaved: () {},
        onDeleted: () =>
            unawaited(FavoritesService.removeFavorite(favourite.id)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: widget.title,
      padding: EdgeInsets.zero,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _buildSearchField(context),
          ),
          Expanded(child: _buildResults(context)),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Row(
      children: [
        Expanded(
          child: CupertinoTextField(
            controller: _controller,
            focusNode: _focus,
            placeholder: 'Search for a place',
            placeholderStyle: TextStyle(
              color: AppColors.black.withValues(alpha: 0.4),
              fontSize: 16,
            ),
            style: TextStyle(color: AppColors.black, fontSize: 16),
            cursorColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.black.withValues(alpha: 0.12),
              ),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(
                LucideIcons.search,
                size: 17,
                color: AppColors.black.withValues(alpha: 0.4),
              ),
            ),
            suffix: _query.isEmpty
                ? null
                : GestureDetector(
                    onTap: _controller.clear,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: AppColors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
            textInputAction: TextInputAction.search,
          ),
        ),
        const SizedBox(width: 10),
        // Some places are easier to point at than to name.
        Semantics(
          button: true,
          label: 'Pick a point on the map',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickOnMap,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Icon(LucideIcons.mapPlus, size: 19, color: accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final query = _query;
    final hasFullQuery = query.length >= 3;

    if (!hasFullQuery) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          if (widget.showMyLocation) ...[
            _ResultRow(
              icon: LucideIcons.locateFixed,
              title: myLocationName,
              subtitle: 'Where you are now',
              onTap: () => _pick(myLocationSuggestion),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.showFavourites) ...[
            _sectionHeading('Favourites'),
            if (_favourites.isEmpty)
              _hint('Tap the heart on a place to keep it here.')
            else
              for (final favourite in _favourites)
                _FavouriteRow(
                  favourite: favourite,
                  onTap: () => _pick(_favouriteToSuggestion(favourite)),
                  onEdit: () => unawaited(_editFavourite(favourite)),
                ),
            const SizedBox(height: 20),
          ],
          if (_recents.isNotEmpty) ...[
            _sectionHeading('Recent'),
            for (final place in _recents.take(8))
              _ResultRow(
                icon: _iconForType(place.type),
                title: place.name,
                subtitle: place.city,
                onTap: () => _pick(_savedToSuggestion(place)),
              ),
          ],
          if (_favourites.isEmpty && _recents.isEmpty && !widget.showFavourites)
            _hint('Start typing to search for a place.'),
        ],
      );
    }

    if (_isFetching && _suggestions.isEmpty) {
      return _hint('Searching…');
    }
    if (_suggestions.isEmpty) {
      return _hint('No matches for “$query”.');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return _ResultRow(
          icon: _iconForType(suggestion.type),
          title: suggestion.name,
          subtitle: suggestion.defaultArea ?? suggestion.country,
          onTap: () => _pick(suggestion),
        );
      },
    );
  }

  Widget _sectionHeading(String text) => Padding(
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

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: AppColors.black.withValues(alpha: 0.5),
      ),
    ),
  );

  TransitousLocationSuggestion _favouriteToSuggestion(FavoritePlace f) =>
      TransitousLocationSuggestion(
        id: 'fav-${f.id}',
        name: f.displayName,
        lat: f.lat,
        lon: f.lon,
        type: 'PLACE',
      );

  TransitousLocationSuggestion _savedToSuggestion(SavedPlace place) =>
      TransitousLocationSuggestion(
        id: 'saved-${place.key}',
        name: place.name,
        lat: place.lat,
        lon: place.lon,
        type: place.type,
      );

  static IconData _iconForType(String type) => switch (type.toUpperCase()) {
    'STOP' => LucideIcons.busFront,
    'ADDRESS' => LucideIcons.locateFixed,
    _ => LucideIcons.mapPin,
  };
}

/// A kept place, with its name and the two ways to rename it.
class _FavouriteRow extends StatelessWidget {
  const _FavouriteRow({
    required this.favourite,
    required this.onTap,
    required this.onEdit,
  });

  final FavoritePlace favourite;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      label: favourite.displayName,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The same actions from a long press, since a three-dot button is a
        // small target and holding the row is the habit people already have.
        onLongPress: onEdit,
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
                child: Icon(
                  iconForFavorite(favourite.iconName),
                  size: 17,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favourite.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                    // Only once the alias says something the name does not,
                    // so an unrenamed favourite is not printed twice.
                    if (favourite.hasAlias)
                      Text(
                        favourite.name,
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
              Semantics(
                button: true,
                label: 'Edit ${favourite.displayName}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Icon(
                      LucideIcons.ellipsisVertical,
                      size: 18,
                      color: AppColors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
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
                  color: accent.withValues(alpha: 0.1),
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
