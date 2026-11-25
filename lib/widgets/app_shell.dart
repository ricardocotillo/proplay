import 'package:material_ui/material_ui.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/widgets/app_top_bar.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// Desktop chrome for the `ShellRoute`: one top bar above every page. On
/// mobile and tablet it renders the page untouched (drawer + own app bars).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveBreakpoints.of(context).largerThan(TABLET)) return child;
    final theme = Theme.of(context);
    // Pages keep their own app bar; flatten it so it reads as a page header.
    final flattened = theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: AppColors.page,
        toolbarHeight: 56,
      ),
    );
    return Material(
      color: AppColors.page,
      child: Column(
        children: [
          AppTopBar(location: location),
          Expanded(
            child: Theme(data: flattened, child: child),
          ),
        ],
      ),
    );
  }
}
