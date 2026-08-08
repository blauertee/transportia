import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/saved_trip.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';

/// Rename or remove a saved trip.
///
/// Naming matters more here than it does for a favourite place: a saved
/// trip's generated label is a route and a timestamp, which is hard to scan
/// in a list of several. Leaving the field empty restores that default
/// rather than forcing a name.
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
    final accent = AppColors.accentOf(context);
    final trip = widget.trip;
    final departure = trip.departureTime.toLocal();

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: const Color(0x80000000),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          LucideIcons.bookmark,
                          size: 24,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saved trip',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${trip.fromName} → ${trip.toName}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.black.withValues(alpha: 0.5),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _nameController,
                    placeholder:
                        '${formatRelativeDay(departure)} '
                        '${formatTime(departure)}',
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.black.withValues(alpha: 0.1),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
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
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.black.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Save',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.solidWhite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _delete,
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
