import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AppColors {
  static Color accentOf(BuildContext context) {
    try {
      return context.watch<ThemeProvider>().accentColor;
    } catch (_) {
      final provider = ThemeProvider.instance;
      if (provider != null) {
        return provider.accentColor;
      }
      try {
        return context.read<ThemeProvider>().accentColor;
      } catch (_) {
        return accent;
      }
    }
  }

  static Color get accent => ThemeProvider.defaultAccentColor;
  static const Color solidBlack = Color(0xFF000000);
  static const Color solidWhite = Color(0xFFFFFFFF);

  /// Disruption: a departure that has gone, or a cancelled service. Muted
  /// rather than alarming, and fixed across themes so it reads the same
  /// whatever accent the user picked.
  static const Color disrupted = Color(0xFFE57373);

  /// A cancelled service, wherever it is spelled out in words. Stronger than
  /// [disrupted], which marks a departure merely gone.
  static const Color cancelled = Color(0xFFD32F2F);

  /// The warning card a service alert is printed on. Fixed hues rather than
  /// theme colours, because a warning that borrows the accent stops looking
  /// like a warning.
  static Color get alertBackground =>
      _isDark ? const Color(0xFF2D2200) : const Color(0xFFFFF3CD);
  static Color get alertBorder =>
      _isDark ? const Color(0xFFB8860B) : const Color(0xFFFFC107);
  static Color get alertIcon =>
      _isDark ? const Color(0xFFFFC107) : const Color(0xFFF57C00);

  static bool get _isDark => ThemeProvider.instance?.isDark ?? false;

  static Color get black =>
      _resolveThemeColor((provider) => provider.textColor, solidBlack);
  static Color get white =>
      _resolveThemeColor((provider) => provider.backgroundColor, solidWhite);

  static Color _resolveThemeColor(
    Color Function(ThemeProvider provider) resolver,
    Color fallback,
  ) {
    final provider = ThemeProvider.instance;
    if (provider == null) {
      return fallback;
    }
    return resolver(provider);
  }
}
