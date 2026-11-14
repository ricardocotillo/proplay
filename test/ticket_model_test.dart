import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/models/ticket_model.dart';

Map<String, dynamic> baseMap() => {
  'sessionId': 's',
  'groupId': 'g',
  'userId': 'u',
  'validationToken': 'tok',
  'status': 'valid',
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
  'eventTitle': 'x',
  'eventDate': Timestamp.fromDate(DateTime.utc(2026, 11, 20)),
  'eventEndDate': Timestamp.fromDate(DateTime.utc(2026, 11, 20, 1)),
  'sport': 'fútbol',
  'userFirstName': 'A',
  'userLastName': 'B',
};

void main() {
  test('toMap writes pricePaid', () {
    final t = TicketModel.fromMap('s_u', {...baseMap(), 'pricePaid': 15});
    final m = t.toMap();
    expect(m['pricePaid'], 15.0);
  });

  test('toMap omits pricePaid when null', () {
    final m = TicketModel.fromMap('s_u', baseMap()).toMap();
    expect(m.containsKey('pricePaid'), isFalse);
  });

  test('legacy doc defaults', () {
    final t = TicketModel.fromMap('s_u', baseMap());
    expect(t.isUsed, isFalse);
    expect(t.pricePaid, isNull);
  });
}
