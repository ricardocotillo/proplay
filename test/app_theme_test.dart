import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/theme/app_theme.dart';

void main() {
  test('AppTheme.dark builds a dark brand theme', () {
    final t = AppTheme.dark;
    expect(t.brightness, Brightness.dark);
    expect(t.colorScheme.primary, const Color(0xFFBA1B1D));
    expect(t.colorScheme.error, isNot(t.colorScheme.primary));
    expect(t.inputDecorationTheme.filled, isTrue);
    expect(t.appBarTheme.backgroundColor, AppColors.bar);
    expect(t.scaffoldBackgroundColor, AppColors.page);
  });
}
