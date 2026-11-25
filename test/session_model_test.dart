import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/session_template_model.dart';

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

  test('bannerUrl is null when absent and omitted from toMap', () {
    final s = SessionModel.fromMap('id', baseMap());
    expect(s.bannerUrl, isNull);
    expect(s.toMap().containsKey('bannerUrl'), isFalse);
  });

  test('bannerUrl roundtrips', () {
    final s = SessionModel.fromMap('id', {
      ...baseMap(),
      'bannerUrl': 'https://x/y.jpg',
    });
    expect(s.bannerUrl, 'https://x/y.jpg');
    expect(s.toMap()['bannerUrl'], 'https://x/y.jpg');
  });

  test('template copyWith sets bannerUrl and keeps cost/duration', () {
    final t = SessionTemplateModel(
      groupId: 'g',
      creatorId: 'u',
      title: 'T',
      eventDate: Timestamp.fromDate(DateTime.utc(2026, 11, 20)),
      eventEndDate: Timestamp.fromDate(DateTime.utc(2026, 11, 20, 1)),
      durationInMinutes: 60,
      maxPlayers: 10,
      totalCost: 100,
      costPerPlayer: 10,
      sport: 'fútbol',
      minAge: 18,
      maxAge: 40,
      desiredGender: 'any',
    );
    expect(t.toMap().containsKey('bannerUrl'), isFalse);
    final c = t.copyWith(bannerUrl: 'https://x/y.jpg');
    expect(c.toMap()['bannerUrl'], 'https://x/y.jpg');
    expect(c.costPerPlayer, 10);
    expect(c.durationInMinutes, 60);
  });
}
