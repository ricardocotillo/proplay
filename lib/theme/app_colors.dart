import 'package:material_ui/material_ui.dart';

/// Palette values the [ColorScheme] cannot hold. Prefer `Theme.of(context)`
/// for anything the scheme already covers.
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFFBA1B1D);
  static const Color page = Color(0xFF0F1115);
  static const Color bar = Color(0xFF16181D);
  static const Color card = Color(0xFF1A1D23);
  static const Color field = Color(0xFF20232A);
  static const Color border = Color(0xFF262A31);
  static const Color text = Color(0xFFF2F3F5);
  static const Color muted = Color(0xFF8A909B);
  static const Color selectedTint = Color(0xFF2A1517);
  static const Color selectedText = Color(0xFFFF5A5C);
  static const Color success = Color(0xFF3DDC84);
  static const Color warning = Color(0xFFFFB020);
  // Distinct from brand red so errors never look like primary actions.
  static const Color error = Color(0xFFFF8A80);

  static const Color heroEnd = Color(0xFF6E0F11);
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand, heroEnd],
  );
}
