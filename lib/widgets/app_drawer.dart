import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/widgets/cached_image.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/screens/credit_history_screen.dart';
import 'package:proplay/screens/credit_approval_screen.dart';
import 'package:proplay/screens/my_tickets_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watchUser;

    return Drawer(
      child: Column(
        children: [
          // Drawer Header with User Info
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            currentAccountPicture: user?.profileImageUrl != null
                ? PlatformCachedImage(
                    imageUrl: user!.profileImageUrl!,
                    imageBuilder: (context, imageProvider) =>
                        CircleAvatar(backgroundImage: imageProvider),
                    placeholder: (context, url) => const CircleAvatar(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      child: Text(
                        user.firstName.isNotEmpty && user.lastName.isNotEmpty
                            ? '${user.firstName[0]}${user.lastName[0]}'
                                  .toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    child: Text(
                      user != null &&
                              user.firstName.isNotEmpty &&
                              user.lastName.isNotEmpty
                          ? '${user.firstName[0]}${user.lastName[0]}'
                                .toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            accountName: Text(
              user != null ? user.fullName : 'Usuario',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              user?.email ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          // Drawer Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Editar Perfil'),
                  onTap: () {
                    context.pop(); // Close drawer
                    context.push('/edit-profile');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Historial de saldo'),
                  onTap: () {
                    context.pop(); // Close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreditHistoryScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: const Text('Mis partidos'),
                  onTap: () {
                    context.pop(); // Close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyTicketsScreen(),
                      ),
                    );
                  },
                ),
                if (user?.superUser == true) ...[
                  const Divider(),
                  ListTile(
                    leading: Icon(
                      Icons.admin_panel_settings,
                      color: AppColors.selectedText,
                    ),
                    title: const Text(
                      'Aprobar Créditos',
                      style: TextStyle(
                        color: AppColors.selectedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      context.pop(); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreditApprovalScreen(),
                        ),
                      );
                    },
                  ),
                ],
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    final authBloc = context.read<AuthBloc>();
                    final router = GoRouter.of(context);
                    // Show confirmation dialog
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Cerrar Sesión'),
                        content: const Text(
                          '¿Estás seguro de que quieres cerrar sesión?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext); // Close dialog
                              context.pop(); // Close the drawer
                              authBloc.add(AuthLogoutRequested());
                              // Not `/login?from=<this page>`: the next
                              // account must not land on this user's page.
                              router.go('/');
                            },
                            child: Text(
                              'Cerrar Sesión',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
