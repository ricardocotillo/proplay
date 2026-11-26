import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/shell_nav.dart';

/// Mobile bottom navigation for signed-in users: the same destinations as the
/// desktop top bar.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final active = activeSection(location);
    final items = navFor(signedIn: true);
    // Every location that shows the bar has a section (tested), so -1 is
    // unreachable; 0 only keeps the widget valid.
    final index = items.indexWhere((i) => i.section == active);
    return NavigationBar(
      backgroundColor: AppColors.bar,
      selectedIndex: index < 0 ? 0 : index,
      onDestinationSelected: (i) => context.go(items[i].path),
      destinations: [
        for (final item in items)
          NavigationDestination(icon: Icon(item.icon), label: item.label),
      ],
    );
  }
}
