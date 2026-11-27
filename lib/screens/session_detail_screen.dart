import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/widgets/cached_image.dart';
import 'package:proplay/widgets/event_bottom_bar.dart';
import 'package:proplay/widgets/event_hero.dart';
import 'package:proplay/widgets/share_event_button.dart';
import 'package:proplay/bloc/session_detail/session_detail_bloc.dart';
import 'package:proplay/bloc/session_detail/session_detail_event.dart';
import 'package:proplay/bloc/session_detail/session_detail_state.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/models/waitlist_entry_model.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/services/ticket_service.dart';
import 'package:proplay/screens/session_map_screen.dart';
import 'package:proplay/utils/app_paths.dart';
import 'package:proplay/utils/attendance_policy.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/join_availability.dart';
import 'package:proplay/utils/min_players.dart';
import 'package:proplay/utils/waitlist_bar.dart';
import 'package:proplay/utils/refund_policy.dart';
import 'package:proplay/widgets/identity_document_dialog.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _wasProcessingJoin = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = context.currentUser!;

    return BlocProvider(
      create: (context) => SessionDetailBloc(
        sessionService: SessionService(),
        groupService: GroupService(userService: UserService()),
        currentUser: currentUser,
      )..add(LoadSessionDetail(widget.sessionId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalles del evento'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/events'),
          ),
          actions: [
            // Only public events have a guest-readable page to share.
            BlocBuilder<SessionDetailBloc, SessionDetailState>(
              builder: (context, state) =>
                  state is SessionDetailLoaded && !state.session.isPrivate
                  ? ShareEventButton(
                      eventId: state.session.id,
                      title: state.session.title,
                    )
                  : const SizedBox.shrink(),
            ),
            BlocBuilder<SessionDetailBloc, SessionDetailState>(
              builder: (context, state) =>
                  state is SessionDetailLoaded && state.isOwnerOrAdmin
                  ? PopupMenuButton<String>(
                      tooltip: 'Opciones del organizador',
                      onSelected: (_) =>
                          _showCancelEventDialog(context, state.session),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'cancel_event',
                          child: Text(
                            'Cancelar evento',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        body: BlocConsumer<SessionDetailBloc, SessionDetailState>(
          listener: (context, state) {
            // Track if we're processing a join action
            if (state is SessionDetailProcessing) {
              if (state.action == 'joining') {
                _wasProcessingJoin = true;
              }
            }

            // If we successfully joined, refresh user credits and redirect to ticket view
            if (state is SessionDetailLoaded &&
                _wasProcessingJoin &&
                state.isCurrentUserJoined) {
              _wasProcessingJoin = false;
              context.read<AuthBloc>().add(const AuthRefreshUserRequested());

              // Redirect to ticket view
              if (mounted) {
                context.push(
                  ticketPath(
                    TicketService.ticketId(state.session.id, currentUser.uid),
                  ),
                );
              }
            }

            if (state is SessionDetailCancelled) {
              context.read<AuthBloc>().add(const AuthRefreshUserRequested());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.refunded
                        ? 'Reembolso acreditado: S/ ${UserModel.formatCredits(state.amount)}'
                        : 'Cupo cancelado, sin reembolso',
                  ),
                ),
              );
            }

            if (state is SessionDetailEventCancelled) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.refunded > 0
                        ? 'Evento cancelado. Devolvimos '
                              'S/ ${UserModel.formatCredits(state.total)} a '
                              '${state.refunded == 1 ? '1 jugador' : '${state.refunded} jugadores'}.'
                        : 'Evento cancelado.',
                  ),
                ),
              );
              // Back to where the user came from (result: the event is gone),
              // or the feed when the page was opened from a link.
              context.canPop() ? context.pop(true) : context.go('/events');
            }

            if (state is SessionDetailError) {
              _wasProcessingJoin = false;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.message,
                    style: const TextStyle(color: Color(0xFF1A0000)),
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is SessionDetailLoading ||
                state is SessionDetailInitial ||
                state is SessionDetailEventCancelled) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is SessionDetailError && state.session == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${state.message}',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // Get session from appropriate state
            final session = (state is SessionDetailLoaded)
                ? state.session
                : (state is SessionDetailProcessing)
                ? state.session
                : (state is SessionDetailCancelled)
                ? state.session
                : (state as SessionDetailError).session!;

            final isLoaded = state is SessionDetailLoaded;
            final isProcessing = state is SessionDetailProcessing;
            final isJoined = isLoaded ? state.isCurrentUserJoined : false;
            final isOwnerOrAdmin = isLoaded ? state.isOwnerOrAdmin : false;
            final presentUids = isLoaded ? state.presentUids : const <String>{};
            final presenceAvailable = !isLoaded || state.presenceAvailable;

            final players = session.players ?? [];
            final hasPlayers = players.isNotEmpty;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      EventHero(session: session),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat.yMMMd().add_jm().format(
                                        session.eventDate,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Hasta: ${DateFormat.jm().format(session.eventEndDate)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.attach_money, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'S/ ${UserModel.formatCredits(session.costPerPlayer)} por jugador',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                                if (session.locationAddress != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                session.locationAddress!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (session.locationLat != null &&
                                          session.locationLng != null)
                                        TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    SessionMapScreen(
                                                      title: session.title,
                                                      latitude:
                                                          session.locationLat!,
                                                      longitude:
                                                          session.locationLng!,
                                                      address: session
                                                          .locationAddress,
                                                    ),
                                              ),
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 0,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            'ver en mapa',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                if (minPlayersNote(
                                      minPlayers: session.minPlayers,
                                      playerCount: players.length,
                                      eventDate: session.eventDate,
                                      now: DateTime.now(),
                                    )
                                    case final note?) ...[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.groups_outlined,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          note,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                // Player count badge
                                _buildBadge(
                                  context,
                                  '${players.length}/${session.maxPlayers}',
                                  'Jugadores',
                                  AppColors.success,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (hasPlayers)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    8,
                                  ),
                                  child: Text(
                                    isOwnerOrAdmin && !presenceAvailable
                                        ? 'Asistencia no disponible'
                                        : isOwnerOrAdmin
                                        ? 'Asistencia: '
                                              '${players.where((p) => presentUids.contains(p.uid)).length}'
                                              '/${players.length} presentes'
                                        : 'Jugadores Confirmados',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                  ),
                                ),
                                ...players.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final player = entry.value;
                                  return _buildPlayerTile(
                                    context,
                                    player,
                                    index + 1,
                                    isOwnerOrAdmin,
                                    presentUids.contains(player.uid),
                                  );
                                }),
                              ],
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: AppColors.muted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay jugadores aún',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: AppColors.muted),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '¡Sé el primero en unirte!',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                EventBottomBar(
                  child: isProcessing
                      ? const Center(child: CircularProgressIndicator())
                      : isJoined
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.success,
                                  width: 2,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: AppColors.success,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Ya estás inscrito en este evento',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => context.push(
                                ticketPath(
                                  TicketService.ticketId(
                                    session.id,
                                    currentUser.uid,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.qr_code),
                              label: const Text('Ver mi Ticket'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                minimumSize: const Size(double.infinity, 0),
                              ),
                            ),
                            // The server rejects cancelling once the event started.
                            if (session.eventDate.isAfter(DateTime.now())) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: isProcessing
                                    ? null
                                    : () => _showCancelDialog(context, session),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancelar mi cupo'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  minimumSize: const Size(double.infinity, 0),
                                ),
                              ),
                            ],
                          ],
                        )
                      : _buildJoinAction(
                          context,
                          session,
                          players.length,
                          isLoaded ? state.waitlist : null,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Bottom bar for someone on the waitlist: waiting, or a seat is held.
  Widget _buildWaitlistAction(
    BuildContext context,
    SessionModel session,
    WaitlistEntryModel waitlist,
  ) {
    final theme = Theme.of(context);
    final bloc = context.read<SessionDetailBloc>();
    final leave = OutlinedButton(
      onPressed: () => bloc.add(const LeaveWaitlist()),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 0),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(waitlist.isOffered ? 'No lo quiero' : 'Salir de la lista'),
    );
    if (!waitlist.isOffered) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'Estás en la lista de espera',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Te avisamos si se libera un cupo. No se cobra hasta que confirmes.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          leave,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HoldCountdown(expiresAt: waitlist.offerExpiresAt),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _showJoinConfirmationDialog(context, session),
          icon: const Icon(Icons.check),
          label: Text(
            'Confirmar y pagar S/ ${UserModel.formatCredits(session.costPerPlayer)}',
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 0),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        leave,
      ],
    );
  }

  /// Bottom bar for a user who has not joined: join, or why they can't.
  Widget _buildJoinAction(
    BuildContext context,
    SessionModel session,
    int playerCount,
    WaitlistEntryModel? waitlist,
  ) {
    // On the waitlist (or holding an offered seat): that decides the bar,
    // whatever the seat count says.
    if (session.eventDate.isAfter(DateTime.now()) &&
        waitlistBar(
              waitlist,
              playerCount: playerCount,
              maxPlayers: session.maxPlayers,
            ) !=
            WaitlistBar.none) {
      return _buildWaitlistAction(context, session, waitlist!);
    }
    final balance = (context.watchUser ?? context.currentUser!).creditsValue;
    final block = joinBlock(
      eventDate: session.eventDate,
      playerCount: playerCount,
      maxPlayers: session.maxPlayers,
      cost: session.costPerPlayer,
      now: DateTime.now(),
      balance: balance,
      blockedUntil: (context.watchUser ?? context.currentUser!).blockedUntil,
    );
    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 12),
      minimumSize: const Size(double.infinity, 0),
    );

    switch (block) {
      case JoinBlock.past:
        return ElevatedButton(
          onPressed: null,
          style: buttonStyle,
          child: const Text('Evento finalizado'),
        );
      case JoinBlock.blocked:
        final until = (context.watchUser ?? context.currentUser!).blockedUntil!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pausa por ausencias: podrás unirte de nuevo el '
              '${blockedUntilLabel(until)}.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.warning),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.push('/politica-asistencia'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Ver política de asistencia'),
            ),
          ],
        );
      case JoinBlock.full:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Evento lleno. Entra a la lista de espera: te avisamos si se '
              'libera un cupo y no se cobra hasta que confirmes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _joinWaitlist(context),
              icon: const Icon(Icons.hourglass_top),
              label: const Text('Unirme a la lista de espera'),
              style: buttonStyle,
            ),
          ],
        );
      case JoinBlock.credits:
        final missing = UserModel.formatCredits(
          session.costPerPlayer - balance,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Te faltan S/ $missing para unirte',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.warning),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                final authBloc = context.read<AuthBloc>();
                // Back here after buying; the balance may have changed.
                context
                    .push('/purchase-credits')
                    .then(
                      (_) => authBloc.add(const AuthRefreshUserRequested()),
                    );
              },
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Recargar saldo'),
              style: buttonStyle,
            ),
          ],
        );
      case JoinBlock.none:
        return ElevatedButton.icon(
          onPressed: () => _showJoinConfirmationDialog(context, session),
          icon: const Icon(Icons.add),
          label: const Text('Unirse al evento'),
          style: buttonStyle,
        );
    }
  }

  Widget _buildBadge(
    BuildContext context,
    String count,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPlayerTile(
    BuildContext context,
    SessionUserModel player,
    int position,
    bool isOwnerOrAdmin,
    bool present,
  ) {
    final initials = '${player.firstName[0]}${player.lastName[0]}'
        .toUpperCase();

    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Position number
          SizedBox(
            width: 24,
            child: Text(
              '$position.',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar
          player.profileImageUrl != null && player.profileImageUrl!.isNotEmpty
              ? CircleAvatar(
                  radius: 20,
                  backgroundImage: platformCachedImageProvider(
                    player.profileImageUrl!,
                  ),
                )
              : CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.success,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
      title: Text(
        '${player.firstName} ${player.lastName}',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _formatJoinTime(player.joinedAt),
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      trailing: isOwnerOrAdmin
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilterChip(
                  tooltip: present
                      ? 'Marcar ausente a ${player.firstName}'
                      : 'Marcar presente a ${player.firstName}',
                  label: const Text('Presente'),
                  selected: present,
                  showCheckmark: true,
                  onSelected: (value) => context.read<SessionDetailBloc>().add(
                    TogglePresence(player.uid, present: value),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'remove') {
                      _showRemoveUserDialog(context, player);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem<String>(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(
                              Icons.remove_circle,
                              size: 18,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Retirar',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            )
          : Icon(Icons.check_circle, color: AppColors.success, size: 20),
    );
  }

  String _formatJoinTime(DateTime joinedAt) {
    final now = DateTime.now();
    final difference = now.difference(joinedAt);

    if (difference.inMinutes < 1) {
      return 'Justo ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'Hace $hours hora${hours > 1 ? 's' : ''}';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return 'Hace $days día${days > 1 ? 's' : ''}';
    } else {
      return DateFormat.MMMd().format(joinedAt);
    }
  }

  /// Legacy accounts have no DNI/CE: ask once before joining (the server
  /// refuses the join without one). False when the player backed out.
  Future<bool> _ensureDocument(BuildContext context) async {
    if (context.currentUser?.hasDocument ?? false) return true;
    return await askIdentityDocument(context) && context.mounted;
  }

  Future<void> _joinWaitlist(BuildContext context) async {
    if (!await _ensureDocument(context) || !context.mounted) return;
    context.read<SessionDetailBloc>().add(const JoinWaitlist());
  }

  Future<void> _showJoinConfirmationDialog(
    BuildContext context,
    SessionModel session,
  ) async {
    if (!await _ensureDocument(context) || !context.mounted) return;
    final cost = UserModel.formatCredits(session.costPerPlayer);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unirse al evento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se descontarán S/ $cost de tu saldo.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Puedes cancelar hasta 24 horas antes del evento y recibir reembolso completo.',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('¿Estás seguro de que quieres continuar?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<SessionDetailBloc>().add(const JoinSession());
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, SessionModel session) {
    final refundable = isRefundable(session.eventDate, DateTime.now());
    final cost = UserModel.formatCredits(session.costPerPlayer);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar mi cupo'),
        content: Text(
          refundable
              ? 'Reembolso completo de S/ $cost.'
              : 'Si cancelas ahora no recibirás reembolso.',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: refundable ? AppColors.success : AppColors.warning,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<SessionDetailBloc>().add(
                const CancelParticipation(),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancelar mi cupo'),
          ),
        ],
      ),
    );
  }

  void _showCancelEventDialog(BuildContext context, SessionModel session) {
    final players = session.players?.length ?? 0;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar evento'),
        content: Text(
          players == 0
              ? 'Se eliminará este evento. No se puede deshacer.'
              : 'Se eliminará este evento y se devolverá lo que pagaron '
                    '${players == 1 ? 'al jugador inscrito' : 'los $players jugadores inscritos'}. '
                    'No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<SessionDetailBloc>().add(const CancelEvent());
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancelar evento'),
          ),
        ],
      ),
    );
  }

  void _showRemoveUserDialog(BuildContext context, SessionUserModel player) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirar jugador'),
        content: Text(
          'Se retirará a ${player.firstName} ${player.lastName} de este '
          'evento y se le devolverá lo que pagó. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<SessionDetailBloc>().add(
                RemoveUserFromSession(player.uid),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
  }
}

/// "Tienes un cupo reservado" with the minutes left, refreshed every 20 s.
class _HoldCountdown extends StatefulWidget {
  final DateTime? expiresAt;

  const _HoldCountdown({required this.expiresAt});

  @override
  State<_HoldCountdown> createState() => _HoldCountdownState();
}

class _HoldCountdownState extends State<_HoldCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.expiresAt?.difference(DateTime.now());
    final minutes = left == null ? 0 : (left.inSeconds / 60).ceil();
    final active = minutes > 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          active ? Icons.timer_outlined : Icons.timer_off_outlined,
          color: active ? AppColors.success : AppColors.warning,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            active ? 'Tienes un cupo reservado: $minutes min para confirmar' : 'Tu reserva venció; si el cupo sigue libre aún puedes confirmar',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}
