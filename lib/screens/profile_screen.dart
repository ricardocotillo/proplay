import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/bloc/attendance/no_shows_cubit.dart';
import 'package:proplay/bloc/notifications/notifications_cubit.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/attendance_service.dart';
import 'package:proplay/utils/attendance_policy.dart';
import 'package:proplay/services/notification_service.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/document.dart';
import 'package:proplay/widgets/cached_image.dart';
import 'package:proplay/widgets/identity_document_dialog.dart';
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

    return Scaffold(
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
                          imageBuilder: (_, image) =>
                              CircleAvatar(radius: 36, backgroundImage: image),
                          placeholder: (_, _) => fallback,
                          errorWidget: (_, _, _) => fallback,
                        ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: theme.textTheme.titleLarge),
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
              _PushSwitch(uid: user.uid),
              _AttendanceTile(uid: user.uid, blockedUntil: user.blockedUntil),
              _DocumentTile(user: user),
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
    );
  }
}

/// "Avisos en el navegador": reminders and saldo approvals as web push.
/// Hidden when web push isn't available (not web, or no VAPID key yet).
class _PushSwitch extends StatelessWidget {
  const _PushSwitch({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotificationsCubit(NotificationService(), uid)..load(),
      child: BlocConsumer<NotificationsCubit, NotificationsState>(
        listenWhen: (_, s) => s.message != null,
        listener: (context, s) =>
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(s.message!))),
        builder: (context, s) {
          if (s.status == PushStatus.unsupported)
            return const SizedBox.shrink();
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
      ),
    );
  }
}

/// Attendance status and a link to the policy.
class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.uid, required this.blockedUntil});

  final String uid;
  final DateTime? blockedUntil;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NoShowsCubit(AttendanceService(), uid)..load(),
      child: BlocBuilder<NoShowsCubit, int?>(
        builder: (context, count) {
          final paused =
              blockedUntil != null && blockedUntil!.isAfter(DateTime.now());
          final subtitle = paused
              ? 'En pausa para unirte hasta el ${blockedUntilLabel(blockedUntil!)}'
              : count == null
              ? 'Cómo contamos las ausencias'
              : count == 0
              ? 'Sin ausencias en los últimos $kNoShowWindowDays días'
              : '$count ausencia${count == 1 ? '' : 's'} en los últimos '
                    '$kNoShowWindowDays días';
          return ListTile(
            leading: Icon(
              paused
                  ? Icons.pause_circle_outline
                  : Icons.event_available_outlined,
              color: paused ? AppColors.warning : null,
            ),
            title: const Text('Política de asistencia'),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/politica-asistencia'),
          );
        },
      ),
    );
  }
}

/// DNI/CE on the account. Tap: add it (legacy), or correct it once every
/// 30 days (the server enforces the limit; the date here is display only).
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final next = nextDocumentChange(user.documentChangedAt, DateTime.now());
    final doc = '${user.documentType.toUpperCase()} ${user.documentNumber}';
    final subtitle = !user.hasDocument
        ? 'Sin documento'
        : next == null
        ? doc
        : '$doc · podrás corregirlo desde el ${blockedUntilLabel(next)}';
    return ListTile(
      leading: const Icon(Icons.badge_outlined),
      title: const Text('Documento de identidad'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        if (!user.hasDocument) {
          await askIdentityDocument(context);
        } else if (next != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Podrás corregir tu documento desde el '
                '${blockedUntilLabel(next)}.',
              ),
            ),
          );
        } else if (await askIdentityDocument(context, correcting: true)) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Documento actualizado')),
          );
        }
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
