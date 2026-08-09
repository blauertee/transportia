import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../utils/haptics.dart';

/// Keeps or discards the options this search is using.
///
/// Options set in the spine last for one search, which is the point: whether
/// you have a bike today should not rewrite what every future search does.
/// The row says so when this search differs, and the two buttons are always
/// there — a control that appears and disappears is harder to find than one
/// that is simply always in the same place.
class SaveDefaultRow extends StatelessWidget {
  const SaveDefaultRow({
    super.key,
    required this.onReset,
    required this.onSaveAsDefault,
    this.differsFromStored = true,
    this.saved = false,
  });

  final VoidCallback onReset;
  final VoidCallback onSaveAsDefault;

  /// Whether this search has been changed from what a new one starts with.
  final bool differsFromStored;

  /// Set once the save lands, so the row can confirm.
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);

    return Row(
      children: [
        Icon(
          saved
              ? LucideIcons.check
              : (differsFromStored
                    ? LucideIcons.pencilLine
                    : LucideIcons.settings2),
          size: 13,
          color: saved ? accent : AppColors.black.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            saved
                ? 'Saved as your default'
                : (differsFromStored
                      ? 'Changed for this search'
                      : 'Using your defaults'),
            style: TextStyle(
              fontSize: 12.5,
              color: saved ? accent : AppColors.black.withValues(alpha: 0.55),
            ),
          ),
        ),
        if (!saved) ...[
          _TextAction(
            label: 'Reset',
            enabled: differsFromStored,
            onPressed: onReset,
          ),
          const SizedBox(width: 14),
          _TextAction(
            label: 'Save as default',
            emphasised: true,
            enabled: differsFromStored,
            onPressed: onSaveAsDefault,
          ),
        ],
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.onPressed,
    this.emphasised = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasised;

  /// Dimmed rather than hidden when there is nothing to do, so the row keeps
  /// its shape and the buttons keep their place.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                Haptics.lightTick();
                onPressed();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? (emphasised
                        ? accent
                        : AppColors.black.withValues(alpha: 0.6))
                  : AppColors.black.withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
  }
}
