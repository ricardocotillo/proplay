import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:proplay/bloc/session/session_bloc.dart';
import 'package:proplay/screens/create_session_screen.dart';
import 'package:proplay/screens/session_detail_screen.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/ticket_url_builder.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:proplay/utils/auth_helper.dart';

class GroupsSessionsScreen extends StatelessWidget {
  final String groupId;
  const GroupsSessionsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.currentUser;

    return BlocProvider(
      create: (context) => SessionBloc(
        sessionService: SessionService(),
        groupService: GroupService(userService: UserService()),
        currentUserId: currentUser?.uid,
      )..add(LoadSessions(groupId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pichangas'),
          actions: [
            BlocBuilder<SessionBloc, SessionState>(
              builder: (context, state) {
                // Only show add button if user is superUser AND owner or admin
                if (state is SessionLoaded &&
                    currentUser?.superUser == true &&
                    (state.currentUserRole == 'owner' ||
                        state.currentUserRole == 'admin')) {
                  return Builder(
                    builder: (builderContext) => TextButton(
                      child: Text(
                        'Crear +',
                        style: const TextStyle(color: Colors.white),
                      ),
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
                  );
                }
                // Return empty container if not authorized
                return const SizedBox.shrink();
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
              // Publishing is curated: group owners/admins who are not
              // verified organizers learn why there is no "Crear +".
              final role = state.currentUserRole;
              final showNotice =
                  (role == 'owner' || role == 'admin') &&
                  currentUser?.superUser != true;
              if (state.sessions.isEmpty) {
                return Column(
                  children: [
                    if (showNotice) const _CuratedNotice(),
                    const Expanded(
                      child: Center(child: Text('No hay próximas pichangas.')),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  if (showNotice) const _CuratedNotice(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.sessions.length,
                      itemBuilder: (context, index) {
                        final session = state.sessions[index];
                        return ListTile(
                          title: Text(session.title),
                          subtitle: Text(
                            DateFormat.yMMMd().add_jm().format(
                              session.eventDate,
                            ),
                          ),
                          trailing: Text(
                            '${session.playerCount}/${session.maxPlayers} jugadores',
                          ),
                          onTap: () async {
                            final bloc = context.read<SessionBloc>();
                            final cancelled = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SessionDetailScreen(sessionId: session.id),
                              ),
                            );
                            if (cancelled == true) {
                              bloc.add(LoadSessions(groupId));
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
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

class _CuratedNotice extends StatelessWidget {
  const _CuratedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_outlined, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Publicar eventos está disponible para organizadores '
                  'verificados.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => launchUrl(
                    supportWhatsAppUri(
                      'Hola, quiero verificar mi grupo en ProPlay para publicar eventos.',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Escríbenos por WhatsApp'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
