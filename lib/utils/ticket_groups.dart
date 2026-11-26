import 'package:proplay/models/ticket_model.dart';

/// "Mis partidos": games not over yet (soonest first) and finished ones
/// (latest first). A game counts as finished once its end time passed.
({List<TicketModel> upcoming, List<TicketModel> past}) splitTickets(
  List<TicketModel> tickets,
  DateTime now,
) {
  final upcoming = tickets.where((t) => t.eventEndDate.isAfter(now)).toList()
    ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
  final past = tickets.where((t) => !t.eventEndDate.isAfter(now)).toList()
    ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
  return (upcoming: upcoming, past: past);
}
