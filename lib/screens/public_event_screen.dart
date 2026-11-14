import 'package:flutter/material.dart';
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
import 'package:proplay/utils/sports.dart';

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
    final sport = kSports.firstWhere(
      (s) => s.value == event.sport,
      orElse: () => kSports.first,
    );
    final signedIn = context.isAuthenticated;

    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              row(sport.icon, sport.display),
              row(
                Icons.calendar_today,
                DateFormat('EEEE d MMMM, HH:mm', 'es').format(event.eventDate),
              ),
              if (event.district != null)
                row(Icons.location_city, event.district!),
              if (event.locationAddress != null)
                row(Icons.place, event.locationAddress!),
              if (event.format != null) row(Icons.view_module, event.format!),
              row(
                Icons.payments,
                event.costPerPlayer > 0
                    ? 'S/ ${UserModel.formatCredits(event.costPerPlayer)} por jugador'
                    : 'Gratis',
              ),
              row(
                Icons.group,
                event.playerCount >= event.maxPlayers
                    ? 'Lleno'
                    : '${event.playerCount}/${event.maxPlayers} cupos',
              ),
              if (event.groupName != null)
                row(Icons.flag, 'Organiza: ${event.groupName}'),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () {
                  if (signedIn) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SessionDetailScreen(sessionId: event.id),
                      ),
                    );
                  } else {
                    context.go('/registration');
                  }
                },
                child: Text(
                  signedIn ? 'Ver evento y unirme' : 'Regístrate para unirte',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
