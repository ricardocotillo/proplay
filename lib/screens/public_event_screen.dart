import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:proplay/bloc/public_event/public_event_bloc.dart';
import 'package:proplay/bloc/public_event/public_event_event.dart';
import 'package:proplay/bloc/public_event/public_event_state.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/screens/session_detail_screen.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/auth_redirect.dart';
import 'package:proplay/utils/join_availability.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/event_format.dart';
import 'package:proplay/widgets/event_bottom_bar.dart';
import 'package:proplay/widgets/event_hero.dart';
import 'package:proplay/widgets/share_event_button.dart';

/// Read-only event detail at `/events/:id`. Safe for guests: it reads the
/// `publicEvents` projection, which never contains the players list.
class PublicEventScreen extends StatelessWidget {
  final String eventId;

  const PublicEventScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PublicEventBloc(sessionService: SessionService())
            ..add(PublicEventStarted(eventId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Evento'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/events'),
          ),
          actions: [
            BlocBuilder<PublicEventBloc, PublicEventState>(
              builder: (context, state) => state is PublicEventLoaded
                  ? ShareEventButton(
                      eventId: state.event.id,
                      title: state.event.title,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        body: BlocBuilder<PublicEventBloc, PublicEventState>(
          builder: (context, state) {
            if (state is PublicEventLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is PublicEventError) {
              return const Center(child: Text('Evento no disponible'));
            }
            return _Details(event: (state as PublicEventLoaded).event);
          },
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final SessionModel event;

  const _Details({required this.event});

  @override
  Widget build(BuildContext context) {
    final signedIn = context.isAuthenticated;
    final seats = seatsInfo(event.playerCount, event.maxPlayers);
    final block = joinBlock(
      eventDate: event.eventDate,
      playerCount: event.playerCount,
      maxPlayers: event.maxPlayers,
      cost: event.costPerPlayer,
      now: DateTime.now(),
    );

    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                EventHero(session: event),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          row(
                            Icons.calendar_today,
                            DateFormat(
                              'EEEE d MMMM, HH:mm',
                              'es',
                            ).format(event.eventDate),
                          ),
                          if (event.district != null)
                            row(Icons.location_city, event.district!),
                          if (event.locationAddress != null)
                            row(Icons.place, event.locationAddress!),
                          if (event.format != null)
                            row(Icons.view_module, event.format!),
                          if (event.groupName != null)
                            row(Icons.flag, 'Organiza: ${event.groupName}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        EventBottomBar(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.costPerPlayer > 0
                          ? 'S/ ${UserModel.formatCredits(event.costPerPlayer)}'
                          : 'Gratis',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: AppColors.selectedText),
                    ),
                    Text(
                      seats.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: seats.urgent
                            ? AppColors.warning
                            : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (signedIn)
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionDetailScreen(sessionId: event.id),
                    ),
                  ),
                  child: const Text('Ver evento y unirme'),
                )
              else
                FilledButton(
                  // Guests sign in (or sign up from login) and come back here.
                  onPressed: block == JoinBlock.none
                      ? () => context.go(
                          authPath('/login', from: '/events/${event.id}'),
                        )
                      : null,
                  child: Text(switch (block) {
                    JoinBlock.past => 'Evento finalizado',
                    JoinBlock.full => 'Evento lleno',
                    _ => 'Ingresa para unirte',
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
