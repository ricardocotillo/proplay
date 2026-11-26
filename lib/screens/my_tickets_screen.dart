import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/bloc/my_tickets/my_tickets_bloc.dart';
import 'package:proplay/bloc/my_tickets/my_tickets_event.dart';
import 'package:proplay/bloc/my_tickets/my_tickets_state.dart';
import 'package:proplay/models/ticket_model.dart';
import 'package:proplay/screens/ticket_detail_screen.dart';
import 'package:proplay/services/ticket_service.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/event_format.dart';
import 'package:proplay/utils/refund_policy.dart';
import 'package:proplay/utils/ticket_groups.dart';

/// "Mis partidos" (`/tickets`): upcoming games first with the free-cancel
/// deadline, finished ones below.
class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.currentUser!;

    return BlocProvider(
      create: (context) =>
          MyTicketsBloc(ticketService: TicketService())
            ..add(LoadMyTickets(currentUser.uid)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Mis partidos')),
        body: BlocBuilder<MyTicketsBloc, MyTicketsState>(
          builder: (context, state) {
            if (state is MyTicketsLoading || state is MyTicketsInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is MyTicketsError) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: AppColors.error),
                    SizedBox(height: 16),
                    Text(
                      'No pudimos cargar tus partidos',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final tickets = (state as MyTicketsLoaded).tickets;
            if (tickets.isEmpty) return const _Empty();

            final now = DateTime.now();
            final split = splitTickets(tickets, now);
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (split.upcoming.isNotEmpty) ...[
                      const _SectionTitle('Próximos'),
                      for (final t in split.upcoming)
                        _TicketCard(ticket: t, now: now),
                    ],
                    if (split.past.isNotEmpty) ...[
                      const _SectionTitle('Anteriores'),
                      for (final t in split.past)
                        _TicketCard(ticket: t, now: now),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_soccer, size: 64, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              'Aún no te has unido a ningún partido',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/events'),
              child: const Text('Ver eventos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final DateTime now;

  const _TicketCard({required this.ticket, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finished = !ticket.eventEndDate.isAfter(now);
    final (statusText, statusColor) = ticket.isUsed
        ? ('Usado', AppColors.muted)
        : finished
        ? ('Finalizado', AppColors.muted)
        : ('Válido', AppColors.success);

    String? cancelNote;
    if (!finished && !ticket.isUsed && ticket.eventDate.isAfter(now)) {
      cancelNote = isRefundable(ticket.eventDate, now)
          ? 'Cancela gratis hasta ${DateFormat('EEE d MMM, HH:mm', 'es').format(ticket.eventDate.subtract(const Duration(hours: 24)))}'
          : 'Si cancelas ahora no hay reembolso';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          Icons.qr_code,
          color: finished ? AppColors.muted : theme.colorScheme.primary,
        ),
        title: Text(ticket.eventTitle, style: theme.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              eventWhenLabel(now, ticket.eventDate),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            if (cancelNote != null) ...[
              const SizedBox(height: 4),
              Text(
                cancelNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                statusText,
                style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketDetailScreen(ticketId: ticket.id),
          ),
        ),
      ),
    );
  }
}
