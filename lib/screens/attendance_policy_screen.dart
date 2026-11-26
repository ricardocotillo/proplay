import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/attendance_policy.dart';

/// Public page (`/politica-asistencia`): what happens when you cancel late or
/// don't show up. Linked from Perfil, the join bar and the push messages.
class AttendancePolicyScreen extends StatelessWidget {
  const AttendancePolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de asistencia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Para que todos puedan jugar',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Un cupo vacío es un partido que se cae. Estas reglas cuidan al grupo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              for (final line in attendancePolicyLines())
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 12),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: AppColors.muted,
                        ),
                      ),
                      Expanded(
                        child: Text(line, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
