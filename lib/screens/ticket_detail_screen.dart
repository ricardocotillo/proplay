import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:proplay/models/ticket_model.dart';
import 'package:proplay/screens/session_map_screen.dart';
import 'package:proplay/services/ticket_service.dart';
import 'package:proplay/utils/ticket_url_builder.dart';

class TicketDetailScreen extends StatelessWidget {
  final String ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Ticket')),
      body: StreamBuilder<TicketModel?>(
        stream: TicketService().streamTicket(ticketId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final ticket = snapshot.data;
          if (ticket == null) {
            return const Center(child: Text('Ticket no encontrado'));
          }

          final url = TicketUrlBuilder.buildValidationUrl(
            ticket.validationToken,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  ticket.eventTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 4),
                    Text(DateFormat.yMMMd().add_jm().format(ticket.eventDate)),
                  ],
                ),
                if (ticket.eventLocationAddress != null) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap:
                        ticket.eventLocationLat != null &&
                            ticket.eventLocationLng != null
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SessionMapScreen(
                                  title: ticket.eventTitle,
                                  latitude: ticket.eventLocationLat!,
                                  longitude: ticket.eventLocationLng!,
                                  address: ticket.eventLocationAddress,
                                ),
                              ),
                            );
                          }
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: ticket.eventLocationLat != null
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            ticket.eventLocationAddress!,
                            style: ticket.eventLocationLat != null
                                ? TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  ticket.userFullName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: ticket.isUsed ? 0.3 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: QrImageView(
                          data: url,
                          version: QrVersions.auto,
                          size: 240,
                          gapless: false,
                        ),
                      ),
                    ),
                    if (ticket.isUsed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'USADO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  url,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  ticket.isUsed
                      ? 'Este ticket ya fue utilizado.'
                      : 'Muestra este código QR al llegar al evento.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
