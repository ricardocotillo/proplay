import 'package:material_ui/material_ui.dart';
import 'package:proplay/theme/app_colors.dart';

/// Fixed bottom action area for the event detail screens.
class EventBottomBar extends StatelessWidget {
  final Widget child;

  const EventBottomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bar,
      shape: const Border(top: BorderSide(color: AppColors.border)),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );
  }
}
