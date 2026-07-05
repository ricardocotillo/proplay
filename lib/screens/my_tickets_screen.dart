import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:proplay/bloc/my_tickets/my_tickets_bloc.dart';
import 'package:proplay/bloc/my_tickets/my_tickets_event.dart';
import 'package:proplay/bloc/my_tickets/my_tickets_state.dart';
import 'package:proplay/models/ticket_model.dart';
import 'package:proplay/screens/ticket_detail_screen.dart';
import 'package:proplay/services/ticket_service.dart';
import 'package:proplay/utils/auth_helper.dart';

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
        appBar: AppBar(title: const Text('Mis Tickets')),
        body: BlocBuilder<MyTicketsBloc, MyTicketsState>(
          builder: (context, state) {
            if (state is MyTicketsLoading || state is MyTicketsInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is MyTicketsError) {
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

            final tickets = (state as MyTicketsLoaded).tickets;

            if (tickets.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes tickets todavía',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                return _TicketCard(ticket: ticket);
              },
            );
          },
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final statusColor = ticket.isUsed ? Colors.grey : Colors.green;
    final statusText = ticket.isUsed ? 'Usado' : 'Válido';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.qr_code, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          ticket.eventTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMd().add_jm().format(ticket.eventDate),
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor, width: 1),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(ticketId: ticket.id),
            ),
          );
        },
      ),
    );
  }
}
