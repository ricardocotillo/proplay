import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/models/session_model.dart';

Map<String, dynamic> baseMap() => {
  'templateId': 't',
  'groupId': 'g',
  'title': 'Pichanga',
  'eventDate': Timestamp.fromDate(DateTime.utc(2026, 11, 20)),
  'eventEndDate': Timestamp.fromDate(DateTime.utc(2026, 11, 20, 1)),
  'status': 'OPEN',
  'playerCount': 1,
  'maxPlayers': 10,
  'costPerPlayer': 15,
  'sport': 'fútbol',
  'minAge': 18,
  'maxAge': 40,
  'desiredGender': 'any',
};

void main() {
  test('fromMap without new fields stays null-safe', () {
    final s = SessionModel.fromMap('id', baseMap());
    expect(s.district, isNull);
    expect(s.format, isNull);
    expect(s.groupName, isNull);
    final m = s.toMap();
    expect(m.containsKey('district'), isFalse);
    expect(m.containsKey('format'), isFalse);
    expect(m.containsKey('groupName'), isFalse);
  });

  test('roundtrip with district and format; groupName never written', () {
    final s = SessionModel.fromMap('id', {
      ...baseMap(),
      'district': 'Miraflores',
      'format': 'Fútbol 7',
      'groupName': 'Los Pibes',
    });
    expect(s.district, 'Miraflores');
    expect(s.format, 'Fútbol 7');
    expect(s.groupName, 'Los Pibes');
    final m = s.toMap();
    expect(m['district'], 'Miraflores');
    expect(m['format'], 'Fútbol 7');
    expect(m.containsKey('groupName'), isFalse);
    final back = SessionModel.fromMap('id', m);
    expect(back.district, 'Miraflores');
    expect(back.format, 'Fútbol 7');
  });
}
