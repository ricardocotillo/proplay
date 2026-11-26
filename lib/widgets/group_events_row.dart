import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/bloc/group/group_state.dart';
import 'package:proplay/bloc/group_events/group_events_cubit.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/utils/app_paths.dart';
import 'package:proplay/widgets/event_card.dart';

/// "De tus grupos" on Home: the next few events from the user's groups, or a
/// pointer to the Grupos tab when there are none.
class GroupEventsRow extends StatelessWidget {
  const GroupEventsRow({super.key});

  static const _shown = 3;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = GroupEventsCubit(SessionService());
        // Back on Home with the groups already loaded: no new GroupLoaded.
        final groups = context.read<GroupBloc>().state;
        if (groups is GroupLoaded) {
          cubit.load([for (final g in groups.groups) g.id]);
        }
        return cubit;
      },
      child: BlocListener<GroupBloc, GroupState>(
        listenWhen: (_, s) => s is GroupLoaded,
        listener: (context, s) => context.read<GroupEventsCubit>().load([
          for (final g in (s as GroupLoaded).groups) g.id,
        ]),
        child: BlocBuilder<GroupEventsCubit, GroupEventsState>(
          builder: (context, state) {
            final theme = Theme.of(context);
            final events = state.events.take(_shown).toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'De tus grupos',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/groups'),
                        child: const Text('Ver grupos'),
                      ),
                    ],
                  ),
                  if (state.loading && events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Cuando tus grupos publiquen eventos, los verás aquí.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  else
                    for (final e in events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: EventCard(
                          session: e,
                          onTap: () => context.push(eventPath(e.id)),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
