import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/favorites_service.dart';
import '../theme/app_colors.dart';
import '../utils/favorite_icons.dart';
import 'overlay_dialog.dart';

/// Side of one icon tile in the picker grid.
const double _kIconTileExtent = 56;

/// Gap between icon tiles, horizontally and vertically.
const double _kIconTileSpacing = 12;

class EditFavoriteOverlay extends StatefulWidget {
  final FavoritePlace favorite;
  final VoidCallback onSaved;

  /// Offered alongside the rename, since a place you no longer keep and a
  /// place you renamed are the same thought a moment apart.
  final VoidCallback? onDeleted;

  const EditFavoriteOverlay({
    super.key,
    required this.favorite,
    required this.onSaved,
    this.onDeleted,
  });

  @override
  State<EditFavoriteOverlay> createState() => _EditFavoriteOverlayState();
}

class _EditFavoriteOverlayState extends State<EditFavoriteOverlay> {
  late TextEditingController _nameController;
  late String _selectedIcon;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.favorite.name);
    _selectedIcon = widget.favorite.iconName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Writes the alias rather than the name.
  ///
  /// The searched name stays underneath, so clearing the field restores it
  /// instead of leaving the place nameless — and a rider who calls a station
  /// "Home" has not forgotten what it is really called.
  Future<void> _saveFavorite() async {
    final alias = _nameController.text.trim();
    final updatedFavorite = widget.favorite.copyWith(
      label: alias,
      clearLabel: alias.isEmpty || alias == widget.favorite.name,
      iconName: _selectedIcon,
    );

    await FavoritesService.updateFavorite(updatedFavorite);
    widget.onSaved();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayDialogCard(
      children: [
        const OverlayDialogHeader(
          icon: LucideIcons.pen,
          title: 'Edit Favourite',
        ),
        const SizedBox(height: 24),
        const OverlayFieldLabel('Name'),
        const SizedBox(height: 8),
        OverlayTextField(
          controller: _nameController,
          placeholder: 'Enter name',
        ),
        const SizedBox(height: 24),
        const OverlayFieldLabel('Icon'),
        const SizedBox(height: 12),
        _IconPickerGrid(
          selectedIcon: _selectedIcon,
          onSelected: (name) => setState(() => _selectedIcon = name),
        ),
        const SizedBox(height: 24),
        if (widget.onDeleted != null) ...[
          _RemoveFavouriteButton(onTap: _remove),
          const SizedBox(height: 8),
        ],
        OverlayDialogActions(
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: _saveFavorite,
        ),
      ],
    );
  }

  void _remove() {
    widget.onDeleted!();
    Navigator.of(context).pop();
  }
}

/// The grid of icons a favourite can be marked with, laid out to as many
/// columns as the dialog is wide enough for.
class _IconPickerGrid extends StatelessWidget {
  const _IconPickerGrid({required this.selectedIcon, required this.onSelected});

  final String selectedIcon;
  final ValueChanged<String> onSelected;

  int _columnsFor(double availableWidth) {
    final fitting =
        (availableWidth / (_kIconTileExtent + _kIconTileSpacing)).floor();
    return fitting.clamp(1, favoriteIconOptions.length);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: favoriteIconOptions.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columnsFor(constraints.maxWidth),
          crossAxisSpacing: _kIconTileSpacing,
          mainAxisSpacing: _kIconTileSpacing,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final option = favoriteIconOptions[index];
          return _IconTile(
            option: option,
            isSelected: selectedIcon == option.name,
            onTap: () => onSelected(option.name),
          );
        },
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final FavoriteIconOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? accent
              : AppColors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? accent
                : AppColors.black.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Icon(
          option.icon,
          size: 24,
          color: isSelected
              ? AppColors.solidWhite
              : AppColors.black.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _RemoveFavouriteButton extends StatelessWidget {
  const _RemoveFavouriteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Remove favourite',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.disrupted,
          ),
        ),
      ),
    );
  }
}
