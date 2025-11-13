import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:proplay/bloc/session_detail/session_detail_bloc.dart';
import 'package:proplay/bloc/session_detail/session_detail_event.dart';
import 'package:proplay/bloc/session_detail/session_detail_state.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/utils/auth_helper.dart';

class SessionDetailScreen extends StatelessWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.currentUser!;

    return BlocProvider(
      create: (context) => SessionDetailBloc(
        sessionService: SessionService(),
        currentUser: currentUser,
      )..add(LoadSessionDetail(sessionId)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Detalles de la Pichanga')),
        body: BlocConsumer<SessionDetailBloc, SessionDetailState>(
          listener: (context, state) {
            if (state is SessionDetailError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is SessionDetailLoading ||
                state is SessionDetailInitial) {
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
                      color: Colors.red,
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
                : (state as SessionDetailError).session!;

            final isLoaded = state is SessionDetailLoaded;
            final isProcessing = state is SessionDetailProcessing;
            final isJoined = isLoaded ? state.isCurrentUserJoined : false;
            final isInWaitingList = isLoaded
                ? state.isCurrentUserInWaitingList
                : false;
            final isOwnerOrAdmin = isLoaded ? state.isOwnerOrAdmin : false;

            final players = session.players ?? [];
            final waitingList = session.waitingList ?? [];
            final hasPlayers = players.isNotEmpty || waitingList.isNotEmpty;

            return Column(
              children: [
                // Session Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat.yMMMd().add_jm().format(
                              session.eventDate,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Hasta: ${DateFormat.yMMMd().add_jm().format(session.eventEndDate)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.attach_money, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'PEN ${session.costPerPlayer.toStringAsFixed(2)} por jugador',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Player count badges
                      Row(
                        children: [
                          _buildBadge(
                            context,
                            '${players.length}/${session.maxPlayers}',
                            'Jugadores',
                            Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _buildBadge(
                            context,
                            '${waitingList.length}/${session.waitingListCount}',
                            'Lista de Espera',
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Player List
                Expanded(
                  child: hasPlayers
                      ? ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            if (players.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  8,
                                ),
                                child: Text(
                                  'Jugadores Confirmados',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
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
                                  false,
                                  isOwnerOrAdmin,
                                );
                              }),
                            ],
                            if (waitingList.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  8,
                                ),
                                child: Text(
                                  'Lista de Espera',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                ),
                              ),
                              ...waitingList.asMap().entries.map((entry) {
                                final index = entry.key;
                                final player = entry.value;
                                return _buildPlayerTile(
                                  context,
                                  player,
                                  index + 1,
                                  true,
                                  isOwnerOrAdmin,
                                );
                              }),
                            ],
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay jugadores aún',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '¡Sé el primero en unirte!',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                ),
                // Action Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: isProcessing
                      ? const Center(child: CircularProgressIndicator())
                      : isJoined || isInWaitingList
                      ? ElevatedButton.icon(
                          onPressed: () {
                            _showLeaveConfirmationDialog(context);
                          },
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text('Salir de la Pichanga'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () {
                            context.read<SessionDetailBloc>().add(
                              const JoinSession(),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: Text(
                            _getJoinButtonText(
                              players.length,
                              session.maxPlayers,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
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
    bool isWaitingList,
    bool isOwnerOrAdmin,
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isWaitingList ? Colors.orange : Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar
          player.profileImageUrl != null && player.profileImageUrl!.isNotEmpty
              ? CircleAvatar(
                  radius: 20,
                  backgroundImage: CachedNetworkImageProvider(
                    player.profileImageUrl!,
                  ),
                )
              : CircleAvatar(
                  radius: 20,
                  backgroundColor: isWaitingList ? Colors.orange : Colors.green,
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
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: isOwnerOrAdmin
          ? PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'remove') {
                  _showRemoveUserDialog(context, player);
                } else if (value == 'move_to_waiting') {
                  _showMoveUserDialog(context, player, toWaitingList: true);
                } else if (value == 'move_to_players') {
                  _showMoveUserDialog(context, player, toWaitingList: false);
                }
              },
              itemBuilder: (BuildContext context) {
                final items = <PopupMenuEntry<String>>[];

                // Move between lists options
                if (isWaitingList) {
                  items.add(
                    const PopupMenuItem<String>(
                      value: 'move_to_players',
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            size: 18,
                            color: Colors.green,
                          ),
                          SizedBox(width: 8),
                          Text('Mover a Jugadores'),
                        ],
                      ),
                    ),
                  );
                } else {
                  items.add(
                    const PopupMenuItem<String>(
                      value: 'move_to_waiting',
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            size: 18,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Text('Mover a Lista de Espera'),
                        ],
                      ),
                    ),
                  );
                }

                // Remove option
                items.add(
                  const PopupMenuItem<String>(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                );

                return items;
              },
            )
          : isWaitingList
          ? Icon(Icons.hourglass_empty, color: Colors.orange[700], size: 20)
          : Icon(Icons.check_circle, color: Colors.green[700], size: 20),
    );
  }

  String _getJoinButtonText(int currentPlayers, int maxPlayers) {
    if (currentPlayers < maxPlayers) {
      return 'Unirse a la Pichanga';
    } else {
      return 'Unirse a Lista de Espera';
    }
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

  void _showLeaveConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Salir de la Pichanga'),
        content: const Text(
          '¿Estás seguro de que quieres salir de esta pichanga?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<SessionDetailBloc>().add(const LeaveSession());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  void _showRemoveUserDialog(BuildContext context, SessionUserModel player) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Jugador'),
        content: Text(
          '¿Estás seguro de que quieres eliminar a ${player.firstName} ${player.lastName} de esta pichanga?',
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showMoveUserDialog(
    BuildContext context,
    SessionUserModel player, {
    required bool toWaitingList,
  }) {
    final String action = toWaitingList
        ? 'mover a la lista de espera'
        : 'mover a la lista de jugadores';
    final String title = toWaitingList
        ? 'Mover a Lista de Espera'
        : 'Mover a Jugadores';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(
          '¿Estás seguro de que quieres $action a ${player.firstName} ${player.lastName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (toWaitingList) {
                context.read<SessionDetailBloc>().add(
                  MoveUserToWaitingList(player.uid),
                );
              } else {
                context.read<SessionDetailBloc>().add(
                  MoveUserToPlayers(player.uid),
                );
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
