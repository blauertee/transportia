import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/favorites_service.dart';
import '../theme/app_colors.dart';
import '../utils/favorite_icons.dart';

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

  final List<FavoriteIconOption> _availableIcons = favoriteIconOptions;

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
                          color: AppColors.accentOf(
                            context,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          LucideIcons.pen,
                          size: 24,
                          color: AppColors.accentOf(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Edit Favourite',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                    placeholder: 'Enter name',
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
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Icon',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const double itemExtent = 56;
                      const double spacing = 12;
                      final availableWidth = constraints.maxWidth;
                      int crossAxisCount =
                          (availableWidth / (itemExtent + spacing)).floor();
                      if (crossAxisCount < 1) {
                        crossAxisCount = 1;
                      } else if (crossAxisCount > _availableIcons.length) {
                        crossAxisCount = _availableIcons.length;
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _availableIcons.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final iconData = _availableIcons[index];
                          final iconName = iconData.name;
                          final icon = iconData.icon;
                          final isSelected = _selectedIcon == iconName;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedIcon = iconName;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accentOf(context)
                                    : AppColors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.accentOf(context)
                                      : AppColors.black.withValues(alpha: 0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Icon(
                                icon,
                                size: 24,
                                color: isSelected
                                    ? AppColors.solidWhite
                                    : AppColors.black.withValues(alpha: 0.6),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  if (widget.onDeleted != null) ...[
                    GestureDetector(
                      onTap: () {
                        widget.onDeleted!();
                        Navigator.of(context).pop();
                      },
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
                    ),
                    const SizedBox(height: 8),
                  ],
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
                          onTap: _saveFavorite,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.accentOf(context),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
