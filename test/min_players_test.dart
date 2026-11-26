import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/utils/min_players.dart';

void main() {
  final now = DateTime(2026, 11, 26, 12);
  final far = now.add(const Duration(hours: 48));

  group('minPlayersError', () {
    String? err(String? v, {int? max = 10, DateTime? start}) =>
        minPlayersError(v, maxPlayers: max, start: start ?? far, now: now);

    test('empty is allowed (no minimum)', () {
      expect(err(''), isNull);
      expect(err(null), isNull);
      expect(err('  '), isNull);
    });
    test('needs a whole number of at least 2, at most the maximum', () {
      expect(err('1'), isNotNull);
      expect(err('0'), isNotNull);
      expect(err('x'), isNotNull);
      expect(err('2.5'), isNotNull);
      expect(err('2'), isNull);
      expect(err('10'), isNull);
      expect(err('11'), contains('máximo'));
      expect(err('5', max: null), isNull);
    });
    test('needs 25 h or more before the start', () {
      expect(
        err('4', start: now.add(const Duration(hours: 24))),
        contains('25 h'),
      );
      expect(err('4', start: now.add(const Duration(hours: 25))), isNull);
      expect(
        minPlayersError('4', maxPlayers: 10, start: null, now: now),
        isNull,
      );
    });
  });

  group('maxPlayersError', () {
    test('1 to the cap is fine', () {
      expect(maxPlayersError('1'), isNull);
      expect(maxPlayersError('22'), isNull);
      expect(maxPlayersError('$kMaxPlayersLimit'), isNull);
    });
    test('empty, 0, text and above the cap are refused', () {
      expect(maxPlayersError(''), isNotNull);
      expect(maxPlayersError(null), isNotNull);
      expect(maxPlayersError('0'), isNotNull);
      expect(maxPlayersError('abc'), isNotNull);
      expect(maxPlayersError('${kMaxPlayersLimit + 1}'), contains('60'));
    });
  });

  group('minPlayersNote', () {
    String? note(int? min, int count, Duration left) => minPlayersNote(
      minPlayers: min,
      playerCount: count,
      eventDate: now.add(left),
      now: now,
    );

    test('no minimum, no line', () {
      expect(note(null, 3, const Duration(hours: 48)), isNull);
      expect(note(1, 0, const Duration(hours: 48)), isNull);
    });
    test('reached: says it is on', () {
      expect(note(4, 4, const Duration(hours: 48)), 'Mínimo alcanzado.');
      expect(note(4, 9, const Duration(hours: 2)), contains('alcanzado'));
    });
    test('short before the check: promises the cancel and refund', () {
      final n = note(6, 3, const Duration(hours: 48))!;
      expect(n, contains('faltan 3'));
      expect(n, contains('se devuelve tu saldo'));
      expect(note(6, 3, const Duration(hours: 24)), isNotNull);
    });
    test('short after the check window: no promise', () {
      expect(note(6, 3, const Duration(hours: 5)), isNull);
      expect(note(6, 3, const Duration(hours: 22)), isNull);
      expect(note(6, 3, const Duration(hours: 23)), isNotNull);
    });
  });

  test('minPlayers round-trips through the model', () {
    final map = {
      'templateId': 't',
      'groupId': 'g',
      'title': 'x',
      'status': 'OPEN',
      'playerCount': 0,
      'maxPlayers': 10,
      'minPlayers': 4,
      'costPerPlayer': 5,
      'sport': 'fútbol',
      'minAge': 0,
      'maxAge': 99,
      'desiredGender': 'any',
    };
    final s = SessionModel.fromMap('e1', map);
    expect(s.minPlayers, 4);
    expect(s.toMap()['minPlayers'], 4);
    // a hand-edited document with a decimal does not crash the parse
    expect(
      SessionModel.fromMap('e3', {...map, 'minPlayers': 4.0}).minPlayers,
      4,
    );
    final none = SessionModel.fromMap('e2', {...map}..remove('minPlayers'));
    expect(none.minPlayers, isNull);
    expect(none.toMap().containsKey('minPlayers'), isFalse);
  });
}
