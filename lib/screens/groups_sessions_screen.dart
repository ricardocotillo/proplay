import 'package:flutter/material.dart';
import 'package:proplay/screens/create_session_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/session/session_bloc.dart';
import 'package:proplay/services/session_service.dart';
import 'package:intl/intl.dart';

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
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                // Capture the bloc before the async navigation
                final sessionBloc = context.read<SessionBloc>();
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateSessionScreen(groupId: groupId),
                  ),
                );
                // Reload sessions if a new session was created
                if (result == true) {
                  sessionBloc.add(LoadSessions(groupId));
                }
              },
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
                  return ListTile(
                    title: Text(session.title),
                    subtitle: Text(
                      DateFormat.yMMMd().add_jm().format(session.eventDate),
                    ),
                    trailing: Text(
                      '${session.playerCount}/${session.maxPlayers} jugadores',
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
