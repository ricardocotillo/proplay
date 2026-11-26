import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/auth_redirect.dart';
import 'package:proplay/utils/shell_nav.dart';
import 'package:proplay/widgets/brand.dart';
import 'package:proplay/widgets/cached_image.dart';
import 'package:proplay/widgets/wallet_indicator.dart';

/// Desktop navigation bar shown on every screen by [AppShell].
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, required this.location});

  final String location;

  /// Guests signing in from an event page come back to it.
  String? get _from => location.startsWith('/events/') ? location : null;

  @override
  Widget build(BuildContext context) {
    final user = context.watchUser;
    final active = activeNavPath(location);
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.bar,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Brand(onTap: () => context.go(user == null ? '/welcome' : '/')),
                const SizedBox(width: 32),
                for (final item in navFor(signedIn: user != null))
                  _NavLink(
                    label: item.label,
                    active: item.path == active,
                    onTap: () => context.go(item.path),
                  ),
                const Spacer(),
                if (user == null) ...[
                  TextButton(
                    onPressed: () =>
                        context.go(authPath('/login', from: _from)),
                    child: const Text('Ingresar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        context.go(authPath('/registration', from: _from)),
                    child: const Text('Crear cuenta'),
                  ),
                ] else ...[
                  WalletIndicator(
                    onTap: () => context.push('/purchase-credits'),
                  ),
                  _AvatarMenu(user: user),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppColors.brand : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: active ? AppColors.selectedText : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({required this.user});

  final UserModel user;

  String get _initials {
    final f = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final l = user.lastName.isNotEmpty ? user.lastName[0] : '';
    final s = '$f$l'.toUpperCase();
    return s.isEmpty ? 'U' : s;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = CircleAvatar(
      radius: 20,
      backgroundColor: scheme.primary,
      child: Text(
        _initials,
        style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold),
      ),
    );
    final url = user.profileImageUrl;
    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      offset: const Offset(0, 48),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            context.push('/edit-profile');
          case 'history':
            context.push('/credit-history');
          case 'approval':
            context.push('/credit-approval');
          case 'logout':
            _confirmLogout(context);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'profile', child: Text('Editar perfil')),
        const PopupMenuItem(
          value: 'history',
          child: Text('Historial de saldo'),
        ),
        if (user.superUser)
          const PopupMenuItem(
            value: 'approval',
            child: Text('Aprobar créditos'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
      ],
      child: url == null
          ? fallback
          : PlatformCachedImage(
              imageUrl: url,
              width: 40,
              height: 40,
              imageBuilder: (_, image) =>
                  CircleAvatar(radius: 20, backgroundImage: image),
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(AuthLogoutRequested());
              // Not `/login?from=<this page>`: the next account must not
              // land on this user's page. `/` resolves to `/welcome`.
              context.go('/');
            },
            child: Text(
              'Cerrar Sesión',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
