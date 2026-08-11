import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/transitous/alert.dart';
import '../theme/app_colors.dart';

/// One service alert, on the warning card every screen prints alerts on.
class AlertNotice extends StatelessWidget {
  const AlertNotice({
    super.key,
    required this.alert,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 8,
    this.titleFontSize = 14,
    this.bodyFontSize = 13,
  });

  /// The tighter proportions the itinerary detail screen prints alerts at,
  /// where they sit inside a leg rather than in a card of their own.
  const AlertNotice.compact({super.key, required this.alert})
    : padding = const EdgeInsets.all(8),
      borderRadius = 4,
      titleFontSize = 13,
      bodyFontSize = 12;

  final Alert alert;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double titleFontSize;
  final double bodyFontSize;

  bool get _hasTitle => alert.headerText?.isNotEmpty == true;
  bool get _hasBody => alert.descriptionText?.isNotEmpty == true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.alertBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.alertBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: 16,
            color: AppColors.alertIcon,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_hasTitle)
                  Text(
                    alert.headerText!,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                if (_hasBody) ...[
                  if (_hasTitle) const SizedBox(height: 2),
                  Text(
                    alert.descriptionText!,
                    style: TextStyle(
                      fontSize: bodyFontSize,
                      color: AppColors.black.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
