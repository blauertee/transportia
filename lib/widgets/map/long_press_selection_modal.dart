import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../theme/app_colors.dart';
import 'map_selection_modal.dart';

/// Decimal places a coordinate is shown to — roughly eleven metres, which is
/// as precise as a long press on a map is anyway.
const int _kCoordinateDecimals = 4;

/// Offers a long-pressed point on the map as an origin or a destination.
class LongPressSelectionModal extends StatelessWidget {
  const LongPressSelectionModal({
    super.key,
    required this.latLng,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onDismissRequested,
    required this.onClosed,
    required this.isClosing,
  });

  final LatLng latLng;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final VoidCallback onDismissRequested;
  final VoidCallback onClosed;
  final bool isClosing;

  String get _coordinates =>
      '${latLng.latitude.toStringAsFixed(_kCoordinateDecimals)}, '
      '${latLng.longitude.toStringAsFixed(_kCoordinateDecimals)}';

  @override
  Widget build(BuildContext context) {
    return MapSelectionModal(
      identity: latLng,
      isClosing: isClosing,
      onClosed: onClosed,
      onDismissRequested: onDismissRequested,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MapModalHeader(
            icon: LucideIcons.mapPin,
            title: 'Use this spot',
            subtitle: _coordinates,
          ),
          const SizedBox(height: 24),
          Text(
            'Choose how to use this location:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          OriginDestinationPicker(
            onSelectFrom: onSelectFrom,
            onSelectTo: onSelectTo,
          ),
          const SizedBox(height: 24),
          MapModalTextAction(
            icon: LucideIcons.x,
            label: 'Dismiss',
            onPressed: onDismissRequested,
          ),
        ],
      ),
    );
  }
}
