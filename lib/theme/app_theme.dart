import 'package:material_ui/material_ui.dart';
import 'package:proplay/theme/app_colors.dart';

/// Single dark theme for the whole app (no light theme by design).
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: AppColors.selectedTint,
      onPrimaryContainer: AppColors.selectedText,
      secondary: AppColors.brand,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.selectedTint,
      onSecondaryContainer: AppColors.selectedText,
      surface: AppColors.card,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: AppColors.page,
      surfaceContainerLow: AppColors.bar,
      surfaceContainer: AppColors.card,
      surfaceContainerHigh: AppColors.field,
      surfaceContainerHighest: AppColors.field,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.error,
      onError: Color(0xFF1A0000),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.page,
    );

    final text = base.textTheme
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text)
        .copyWith(
          headlineSmall: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          bodyMedium: const TextStyle(fontSize: 14, color: AppColors.text),
          bodySmall: const TextStyle(fontSize: 12, color: AppColors.muted),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        );

    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bar,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.field,
          disabledForegroundColor: AppColors.muted,
          elevation: 0,
          padding: buttonPadding,
          shape: pill,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          padding: buttonPadding,
          shape: pill,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          padding: buttonPadding,
          shape: pill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.selectedText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: AppColors.muted),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        border: inputBorder(AppColors.border),
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(AppColors.brand, 2),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error, 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.selectedTint,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(color: AppColors.text),
        secondaryLabelStyle: const TextStyle(color: AppColors.selectedText),
        checkmarkColor: AppColors.selectedText,
        shape: const StadiumBorder(),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.field,
        contentTextStyle: const TextStyle(color: AppColors.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.muted,
        textColor: AppColors.text,
        selectedColor: AppColors.selectedText,
        selectedTileColor: AppColors.selectedTint,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.brand : AppColors.field,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.brand : null,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.muted, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.brand : AppColors.muted,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.selectedText,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.brand,
        dividerColor: AppColors.border,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
      iconTheme: const IconThemeData(color: AppColors.text),
    );
  }
}
