import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/models/ticket_model.dart';
import 'package:proplay/utils/ticket_groups.dart';

TicketModel ticket(String id, DateTime start) => TicketModel.fromMap(id, {
  'sessionId': id,
  'groupId': 'g',
  'userId': 'u',
  'validationToken': 'tok',
  'status': 'valid',
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
  'eventTitle': id,
  'eventDate': Timestamp.fromDate(start),
  'eventEndDate': Timestamp.fromDate(start.add(const Duration(hours: 2))),
  'sport': 'fútbol',
  'userFirstName': 'A',
  'userLastName': 'B',
});

void main() {
  final now = DateTime.utc(2026, 11, 26, 20);

  test('splits by end time and sorts each side', () {
    final r = splitTickets([
      ticket('lastWeek', now.subtract(const Duration(days: 7))),
      ticket('nextWeek', now.add(const Duration(days: 7))),
      ticket('yesterday', now.subtract(const Duration(days: 1))),
      ticket('tomorrow', now.add(const Duration(days: 1))),
    ], now);
    expect(r.upcoming.map((t) => t.id), ['tomorrow', 'nextWeek']);
    expect(r.past.map((t) => t.id), ['yesterday', 'lastWeek']);
  });

  test('a game in progress is still upcoming', () {
    final r = splitTickets([
      ticket('live', now.subtract(const Duration(hours: 1))),
    ], now);
    expect(r.upcoming.single.id, 'live');
    expect(r.past, isEmpty);
  });
}
