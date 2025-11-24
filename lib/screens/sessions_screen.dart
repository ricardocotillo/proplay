import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:proplay/bloc/session/session_bloc.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/bloc/group/group_state.dart';
import 'package:proplay/screens/session_detail_screen.dart';
import 'package:proplay/services/session_service.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pichangas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: BlocBuilder<GroupBloc, GroupState>(
        builder: (context, groupState) {
          if (groupState is GroupLoaded) {
            final groupIds = groupState.groups.map((g) => g.id).toList();

            return BlocProvider(
              create: (context) => SessionBloc(
                sessionService: SessionService(),
              )..add(LoadAllUserSessions(groupIds)),
              child: BlocBuilder<SessionBloc, SessionState>(
                builder: (context, sessionState) {
                  if (sessionState is SessionLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (sessionState is SessionLoaded) {
                    if (sessionState.sessions.isEmpty) {
                      return const Center(
                        child: Text('No hay próximas pichangas.'),
                      );
                    }

                    return ListView.builder(
                      itemCount: sessionState.sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessionState.sessions[index];
                        return ListTile(
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
                                builder: (context) => SessionDetailScreen(
                                  sessionId: session.id,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }

                  if (sessionState is SessionError) {
                    return Center(child: Text('Error: ${sessionState.message}'));
                  }

                  return const Center(
                    child: Text('Las próximas pichangas se mostrarán aquí.'),
                  );
                },
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
