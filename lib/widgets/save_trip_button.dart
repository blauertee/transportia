import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/itinerary.dart';
import '../models/saved_trip.dart';
import '../services/saved_trips_service.dart';
import '../theme/app_colors.dart';
import '../utils/haptics.dart';
import 'validation_toast.dart';

/// Bookmark toggle for keeping a connection.
///
/// Shared by the results list and the detail screen so the two cannot drift:
/// both read the same stored state, so a trip saved from one immediately
/// shows as saved in the other.
///
/// Renders nothing for an itinerary that cannot be stored — one built in
/// code rather than parsed from the planner, or one with no legs.
class SaveTripButton extends StatefulWidget {
  const SaveTripButton({
    super.key,
    required this.itinerary,
    this.size = 20,
    this.padding = const EdgeInsets.all(6),
  });

  final Itinerary itinerary;
  final double size;
  final EdgeInsetsGeometry padding;

  @override
  State<SaveTripButton> createState() => _SaveTripButtonState();
}

class _SaveTripButtonState extends State<SaveTripButton> {
  SavedTrip? _trip;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _trip = _buildTrip();
    // Populate the listenable so the icon reflects stored state on first
    // build rather than flicking from unsaved to saved.
    unawaited(SavedTripsService.getSavedTrips());
  }

  @override
  void didUpdateWidget(SaveTripButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.itinerary, widget.itinerary)) {
      _trip = _buildTrip();
    }
  }

  SavedTrip? _buildTrip() {
    try {
      return SavedTrip.fromItinerary(itinerary: widget.itinerary);
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _toggle(bool isSaved) async {
    final trip = _trip;
    if (trip == null || _isBusy) return;

    setState(() => _isBusy = true);
    unawaited(Haptics.lightTick());

    try {
      if (isSaved) {
        await SavedTripsService.removeTrip(trip.id);
      } else {
        await SavedTripsService.saveTrip(trip);
      }
      if (!mounted) return;
      showValidationToast(
        context,
        isSaved ? 'Trip removed' : 'Trip saved',
        accentColor: AppColors.accentOf(context),
      );
    } catch (_) {
      if (!mounted) return;
      showValidationToast(context, 'Could not update saved trips.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    if (trip == null) return const SizedBox.shrink();

    return ValueListenableBuilder<List<SavedTrip>>(
      valueListenable: SavedTripsService.savedTripsListenable,
      builder: (context, savedTrips, _) {
        final isSaved = savedTrips.any((t) => t.id == trip.id);
        final accent = AppColors.accentOf(context);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggle(isSaved),
          child: Padding(
            padding: widget.padding,
            child: Icon(
              isSaved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
              size: widget.size,
              color: isSaved ? accent : AppColors.black.withValues(alpha: 0.45),
            ),
          ),
        );
      },
    );
  }
}
