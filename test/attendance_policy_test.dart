import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/bloc/attendance/no_shows_cubit.dart';
import 'package:proplay/services/attendance_service.dart';
import 'package:proplay/utils/attendance_policy.dart';
import 'package:proplay/utils/auth_redirect.dart';
import 'package:proplay/utils/join_availability.dart';

class _FakeAttendance implements AttendanceService {
  int? count = 2;
  bool fail = false;

  @override
  Future<int> recentNoShows(String uid) async {
    if (fail) throw Exception('denied');
    return count!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the published policy states the numbers the server enforces', () {
    final text = attendancePolicyLines().join('\n');
    expect(text, contains('$kNoShowWindowDays días'));
    expect(text, contains('$kNoShowBlockDays días'));
    expect([kNoShowWarnAt, kNoShowBlockAt], [2, 3]);
    expect(text, contains('24 h'));
    expect(text, contains('lista de espera'));
    expect(text.toLowerCase(), isNot(contains('pichanga')));
  });

  group('joinBlock with a pause', () {
    final now = DateTime(2026, 11, 26, 12);
    JoinBlock block({DateTime? until, int players = 3, double? balance = 50}) =>
        joinBlock(
          eventDate: now.add(const Duration(days: 3)),
          playerCount: players,
          maxPlayers: 10,
          cost: 10,
          now: now,
          balance: balance,
          blockedUntil: until,
        );

    test('an active pause blocks, even with seats and saldo', () {
      expect(block(until: now.add(const Duration(days: 2))), JoinBlock.blocked);
    });
    test('an expired or missing pause does not', () {
      expect(
        block(until: now.subtract(const Duration(hours: 1))),
        JoinBlock.none,
      );
      expect(block(), JoinBlock.none);
    });
    test('a past event is final, before the pause', () {
      expect(
        joinBlock(
          eventDate: now.subtract(const Duration(hours: 1)),
          playerCount: 0,
          maxPlayers: 10,
          cost: 10,
          now: now,
          blockedUntil: now.add(const Duration(days: 2)),
        ),
        JoinBlock.past,
      );
    });
  });

  test('the policy page is open to guests', () {
    expect(
      authRedirect(
        loggedIn: false,
        location: '/politica-asistencia',
        target: '/politica-asistencia',
      ),
      isNull,
    );
  });

  test('NoShowsCubit loads the count and degrades to null', () async {
    final service = _FakeAttendance();
    final cubit = NoShowsCubit(service, 'u1');
    await cubit.load();
    expect(cubit.state, 2);
    service.fail = true;
    await cubit.load();
    expect(cubit.state, isNull);
  });
}
