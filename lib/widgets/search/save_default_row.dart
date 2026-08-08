import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../utils/haptics.dart';

/// Says that this search is not the usual one, and offers the two ways out.
///
/// Options set in the spine last for one search, which is the point: whether
/// you have a bike today should not rewrite what every future search does.
/// This appears only once something differs, so the ordinary case carries no
/// extra row, and it names the difference rather than leaving the user to
/// spot it.
class SaveDefaultRow extends StatelessWidget {
  const SaveDefaultRow({
    super.key,
    required this.onReset,
    required this.onSaveAsDefault,
    this.saved = false,
  });

  final VoidCallback onReset;
  final VoidCallback onSaveAsDefault;

  /// Set once the save lands, so the row can confirm before it goes away.
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);

    return Row(
      children: [
        Icon(
          saved ? LucideIcons.check : LucideIcons.pencilLine,
          size: 13,
          color: saved ? accent : AppColors.black.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            saved ? 'Saved as your default' : 'Changed for this search',
            style: TextStyle(
              fontSize: 12.5,
              color: saved ? accent : AppColors.black.withValues(alpha: 0.55),
            ),
          ),
        ),
        if (!saved) ...[
          _TextAction(label: 'Reset', onPressed: onReset),
          const SizedBox(width: 14),
          _TextAction(
            label: 'Save as default',
            emphasised: true,
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
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.lightTick();
          onPressed();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: emphasised
                  ? accent
                  : AppColors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
