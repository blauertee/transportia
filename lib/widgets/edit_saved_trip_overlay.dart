import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/saved_trip.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';
import 'overlay_dialog.dart';

/// Rename or remove a saved trip.
///
/// Leaving the field empty restores the generated label — a route and a
/// timestamp — rather than forcing a name.
class EditSavedTripOverlay extends StatefulWidget {
  const EditSavedTripOverlay({
    super.key,
    required this.trip,
    required this.onRename,
    required this.onDelete,
  });

  final SavedTrip trip;

  /// Called with the new name, or null to fall back to the generated label.
  final ValueChanged<String?> onRename;

  final VoidCallback onDelete;

  @override
  State<EditSavedTripOverlay> createState() => _EditSavedTripOverlayState();
}

class _EditSavedTripOverlayState extends State<EditSavedTripOverlay> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.trip.label ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    widget.onRename(name.isEmpty ? null : name);
    Navigator.of(context).pop();
  }

  void _delete() {
    widget.onDelete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final departure = trip.departureTime.toLocal();

    return OverlayDialogCard(
      children: [
        OverlayDialogHeader(
          icon: LucideIcons.bookmark,
          title: 'Saved trip',
          subtitle: '${trip.fromName} → ${trip.toName}',
        ),
        const SizedBox(height: 20),
        const OverlayFieldLabel('Name'),
        const SizedBox(height: 8),
        OverlayTextField(
          controller: _nameController,
          placeholder:
              '${formatRelativeDay(departure)} ${formatTime(departure)}',
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 8),
        Text(
          'Leave empty to use the departure time.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.black.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 24),
        OverlayDialogActions(
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: _save,
        ),
        const SizedBox(height: 12),
        _RemoveTripButton(onTap: _delete),
      ],
    );
  }
}

class _RemoveTripButton extends StatelessWidget {
  const _RemoveTripButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.disrupted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.trash2,
              size: 18,
              color: AppColors.disrupted,
            ),
            const SizedBox(width: 8),
            Text(
              'Remove trip',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.disrupted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
