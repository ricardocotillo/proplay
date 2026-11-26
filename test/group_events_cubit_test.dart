import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/bloc/group_events/group_events_cubit.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/services/session_service.dart';

SessionModel _event(String id) => SessionModel(
  id: id,
  templateId: 't',
  groupId: 'g1',
  title: id,
  eventDate: DateTime(2030),
  eventEndDate: DateTime(2030),
  status: 'OPEN',
  playerCount: 0,
  maxPlayers: 10,
  costPerPlayer: 10,
  sport: 'fútbol',
  minAge: 0,
  maxAge: 99,
  desiredGender: 'any',
);

class _FakeSessions implements SessionService {
  List<String>? asked;
  bool fail = false;

  /// When set, the next call waits for it before answering.
  Completer<void>? gate;

  @override
  Future<List<SessionModel>> getUpcomingSessionsForGroups(
    List<String> groupIds,
  ) async {
    asked = groupIds;
    final wait = gate;
    gate = null;
    await wait?.future;
    if (fail) throw Exception('boom');
    return groupIds.contains('old')
        ? [_event('stale')]
        : [_event('a'), _event('b')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('loads the events of the given groups', () async {
    final sessions = _FakeSessions();
    final cubit = GroupEventsCubit(sessions);
    await cubit.load(['g1', 'g2']);
    expect(sessions.asked, ['g1', 'g2']);
    expect(cubit.state.events.map((e) => e.id), ['a', 'b']);
    expect(cubit.state.loading, isFalse);
  });

  test('no groups: nothing to load, no query', () async {
    final sessions = _FakeSessions();
    final cubit = GroupEventsCubit(sessions);
    await cubit.load(const []);
    expect(sessions.asked, isNull);
    expect(cubit.state.events, isEmpty);
  });

  test('a failed load leaves an empty row, never an error', () async {
    final cubit = GroupEventsCubit(_FakeSessions()..fail = true);
    await cubit.load(['g1']);
    expect(cubit.state.events, isEmpty);
    expect(cubit.state.loading, isFalse);
  });

  test('a slower, older load never overwrites the newer one', () async {
    final gate = Completer<void>();
    final sessions = _FakeSessions()..gate = gate;
    final cubit = GroupEventsCubit(sessions);
    final slow = cubit.load(['old']); // waits on the gate
    await cubit.load(['g1']);
    expect(cubit.state.events.map((e) => e.id), ['a', 'b']);
    gate.complete();
    await slow;
    expect(cubit.state.events.map((e) => e.id), ['a', 'b']);
  });
}
