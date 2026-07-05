import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:proplay/bloc/validate_ticket/validate_ticket_bloc.dart';
import 'package:proplay/bloc/validate_ticket/validate_ticket_event.dart';
import 'package:proplay/bloc/validate_ticket/validate_ticket_state.dart';
import 'package:proplay/models/ticket_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/ticket_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/utils/auth_helper.dart';

class ValidateTicketScreen extends StatelessWidget {
  final String? token;

  const ValidateTicketScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.currentUser!;

    return BlocProvider(
      create: (context) =>
          ValidateTicketBloc(
              ticketService: TicketService(),
              groupService: GroupService(userService: UserService()),
              currentUser: currentUser,
            )
            ..add(LoadTicketByToken(token)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Validar Ticket')),
        body: BlocConsumer<ValidateTicketBloc, ValidateTicketState>(
          listener: (context, state) {
            if (state is ValidateTicketError && state.ticket == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is ValidateTicketLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ValidateTicketNotFound) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Ticket no válido o no encontrado',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is ValidateTicketSuccess) {
              return _buildSuccess(context, state.ticket);
            }

            if (state is ValidateTicketError && state.ticket == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Error: ${state.message}',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final ticket = switch (state) {
              ValidateTicketLoaded(:final ticket) => ticket,
              ValidateTicketProcessing(:final ticket) => ticket,
              ValidateTicketError(:final ticket?) => ticket,
              _ => null,
            };
            final isOwnerOrAdmin = switch (state) {
              ValidateTicketLoaded(:final isOwnerOrAdmin) => isOwnerOrAdmin,
              ValidateTicketProcessing(:final isOwnerOrAdmin) =>
                isOwnerOrAdmin,
              ValidateTicketError(:final isOwnerOrAdmin) => isOwnerOrAdmin,
              _ => false,
            };
            final isProcessing = state is ValidateTicketProcessing;

            if (ticket == null) {
              return const SizedBox.shrink();
            }

            return _buildTicketSummary(
              context,
              ticket,
              isOwnerOrAdmin,
              isProcessing,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTicketSummary(
    BuildContext context,
    TicketModel ticket,
    bool isOwnerOrAdmin,
    bool isProcessing,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.eventTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat.yMMMd().add_jm().format(ticket.eventDate),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 4),
                      Text(ticket.userFullName),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (ticket.isUsed ? Colors.grey : Colors.green)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ticket.isUsed ? Colors.grey : Colors.green,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      ticket.isUsed ? 'Usado' : 'Válido',
                      style: TextStyle(
                        color: ticket.isUsed ? Colors.grey[700] : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (ticket.isUsed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticket.usedAt != null
                          ? 'Este ticket ya fue utilizado el ${DateFormat.yMMMd().add_jm().format(ticket.usedAt!)}.'
                          : 'Este ticket ya fue utilizado.',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            )
          else if (isOwnerOrAdmin)
            ElevatedButton.icon(
              onPressed: isProcessing
                  ? null
                  : () => _showConfirmDialog(context),
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('Marcar como Usado'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 48),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No tienes permisos para validar este ticket',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context, TicketModel ticket) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Ticket validado correctamente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              ticket.userFullName,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil(
                (route) => route.isFirst,
              ),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Marcar como Usado'),
        content: const Text(
          '¿Confirmas que este ticket debe marcarse como usado? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<ValidateTicketBloc>().add(
                const ConfirmValidateTicket(),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
