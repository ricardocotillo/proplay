import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/bloc/notifications/notifications_cubit.dart';
import 'package:proplay/services/notification_service.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/widgets/cached_image.dart';
import 'package:proplay/widgets/logout_dialog.dart';
import 'package:proplay/widgets/wallet_indicator.dart';

/// "Perfil" tab: who you are, saldo, and the account pages that used to live
/// in the drawer.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watchUser;
    final theme = Theme.of(context);
    if (user == null) return const SizedBox.shrink();
    final initials = [
      user.firstName,
      user.lastName,
    ].where((n) => n.isNotEmpty).map((n) => n[0]).join().toUpperCase();
    final fallback = CircleAvatar(
      radius: 36,
      backgroundColor: theme.colorScheme.primary,
      child: Text(
        initials.isEmpty ? 'U' : initials,
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    final url = user.profileImageUrl;

    return BlocProvider(
      create: (_) =>
          NotificationsCubit(NotificationService(), user.uid)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    url == null
                        ? fallback
                        : PlatformCachedImage(
                            imageUrl: url,
                            width: 72,
                            height: 72,
                            imageBuilder: (_, image) => CircleAvatar(
                              radius: 36,
                              backgroundImage: image,
                            ),
                            placeholder: (_, _) => fallback,
                            errorWidget: (_, _, _) => fallback,
                          ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: theme.textTheme.titleLarge,
                          ),
                          Text(
                            user.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Saldo'),
                    trailing: WalletIndicator(
                      onTap: () => context.push('/purchase-credits'),
                    ),
                    onTap: () => context.push('/purchase-credits'),
                  ),
                ),
                const SizedBox(height: 8),
                const _PushSwitch(),
                _Tile(
                  icon: Icons.edit_outlined,
                  title: 'Editar perfil',
                  onTap: () => context.push('/edit-profile'),
                ),
                _Tile(
                  icon: Icons.history,
                  title: 'Historial de saldo',
                  onTap: () => context.push('/credit-history'),
                ),
                if (user.superUser)
                  _Tile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Aprobar saldo',
                    color: AppColors.selectedText,
                    onTap: () => context.push('/credit-approval'),
                  ),
                const Divider(height: 32),
                _Tile(
                  icon: Icons.logout,
                  title: 'Cerrar sesión',
                  color: AppColors.error,
                  onTap: () => confirmLogout(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Avisos en el navegador": reminders and saldo approvals as web push.
/// Hidden when web push isn't available (not web, or no VAPID key yet).
class _PushSwitch extends StatelessWidget {
  const _PushSwitch();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationsCubit, NotificationsState>(
      listenWhen: (_, s) => s.message != null,
      listener: (context, s) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(s.message!))),
      builder: (context, s) {
        if (s.status == PushStatus.unsupported) return const SizedBox.shrink();
        return SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Avisos en el navegador'),
          subtitle: Text(
            s.status == PushStatus.blocked
                ? 'Bloqueados en tu navegador'
                : 'Recordatorios de tus eventos y saldo aprobado',
          ),
          value: s.status == PushStatus.on,
          onChanged: s.busy || s.status == PushStatus.blocked
              ? null
              : (v) => context.read<NotificationsCubit>().set(v),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(title, style: TextStyle(color: color)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
