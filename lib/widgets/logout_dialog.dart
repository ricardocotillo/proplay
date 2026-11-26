import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/theme/app_colors.dart';

/// Confirm, then log out. Shared by the top bar and the Perfil tab.
void confirmLogout(BuildContext context) {
  final authBloc = context.read<AuthBloc>();
  final router = GoRouter.of(context);
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            authBloc.add(AuthLogoutRequested());
            // Not `/login?from=<this page>`: the next account must not land
            // on this user's page. `/` resolves to `/welcome`.
            router.go('/');
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
}
