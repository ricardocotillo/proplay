import 'package:material_ui/material_ui.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/shell_nav.dart';
import 'package:proplay/widgets/app_bottom_nav.dart';
import 'package:proplay/widgets/app_top_bar.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// Chrome for the `ShellRoute`: a top bar above every page on desktop; on
/// mobile and tablet a bottom bar for signed-in users on the top level of each
/// destination. Pages keep their own app bars.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveBreakpoints.of(context).largerThan(TABLET)) {
      if (context.watchUser == null || !showsBottomNav(location)) return child;
      final media = MediaQuery.of(context);
      // Keyboard open: no bar (nothing on these pages needs it meanwhile).
      if (media.viewInsets.bottom > 0) return child;
      // The bar handles the bottom safe area itself; the page above it must
      // not reserve it again.
      return Column(
        children: [
          Expanded(
            child: MediaQuery(
              data: media.copyWith(
                padding: media.padding.copyWith(bottom: 0),
                viewPadding: media.viewPadding.copyWith(bottom: 0),
              ),
              child: child,
            ),
          ),
          AppBottomNav(location: location),
        ],
      );
    }
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
