import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:proplay/bloc/session/session_bloc.dart';
import 'package:proplay/screens/create_session_screen.dart';
import 'package:proplay/screens/session_detail_screen.dart';
import 'package:proplay/services/session_service.dart';

class GroupsSessionsScreen extends StatelessWidget {
  final String groupId;
  const GroupsSessionsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SessionBloc(sessionService: SessionService())
            ..add(LoadSessions(groupId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pichangas'),
          actions: [
            Builder(
              builder: (builderContext) => IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  // Capture the bloc before the async navigation
                  final sessionBloc = builderContext.read<SessionBloc>();
                  final result = await Navigator.push(
                    builderContext,
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateSessionScreen(groupId: groupId),
                    ),
                  );
                  // Reload sessions if a new session was created
                  if (result == true) {
                    sessionBloc.add(LoadSessions(groupId));
                  }
                },
              ),
            ),
          ],
        ),
        body: BlocBuilder<SessionBloc, SessionState>(
          builder: (context, state) {
            if (state is SessionLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is SessionLoaded) {
              if (state.sessions.isEmpty) {
                return const Center(child: Text('No hay próximas pichangas.'));
              }
              return ListView.builder(
                itemCount: state.sessions.length,
                itemBuilder: (context, index) {
                  final session = state.sessions[index];
                  return Dismissible(
                    key: Key(session.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                title: const Text('Eliminar sesión'),
                                content: const Text(
                                  '¿Estás seguro de que quieres eliminar esta sesión? '
                                  'Esta acción no se puede deshacer.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              );
                            },
                          ) ??
                          false;
                    },
                    onDismissed: (direction) {
                      context.read<SessionBloc>().add(
                        DeleteSession(session.id),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${session.title} eliminada')),
                      );
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20.0),
                      color: Colors.red,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.delete, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Eliminar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: ListTile(
                      title: Text(session.title),
                      subtitle: Text(
                        DateFormat.yMMMd().add_jm().format(session.eventDate),
                      ),
                      trailing: Text(
                        '${session.playerCount}/${session.maxPlayers} jugadores',
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SessionDetailScreen(sessionId: session.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }
            if (state is SessionError) {
              return Center(child: Text('Error: ${state.message}'));
            }
            return const Center(
              child: Text('Las próximas pichangas se mostrarán aquí.'),
            );
          },
        ),
      ),
    );
  }
}
