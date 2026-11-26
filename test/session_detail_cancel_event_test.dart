import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/bloc/session_detail/session_detail_bloc.dart';
import 'package:proplay/bloc/session_detail/session_detail_event.dart';
import 'package:proplay/bloc/session_detail/session_detail_state.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/models/waitlist_entry_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/utils/manage_event.dart';

final _session = SessionModel(
  id: 's1',
  templateId: 't1',
  groupId: 'g1',
  title: 'Pichanga',
  eventDate: DateTime(2030),
  eventEndDate: DateTime(2030, 1, 1, 2),
  status: 'OPEN',
  playerCount: 0,
  maxPlayers: 10,
  costPerPlayer: 10,
  sport: 'fútbol',
  minAge: 0,
  maxAge: 99,
  desiredGender: 'any',
);

/// Server stand-in: cancelEvent may delete the event (its stream then
/// errors with not found) and may still fail (timeout after commit).
class _FakeSessions implements SessionService {
  bool deleted = false;
  bool deleteOnCancel = true;
  Object? cancelError;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<SessionModel> streamSession(String sessionId) async* {
    if (deleted) throw Exception('Evento no encontrado.');
    yield _session;
    await for (final _ in _changes.stream) {
      if (deleted) throw Exception('Evento no encontrado.');
      yield _session;
    }
  }

  final waitlist = StreamController<WaitlistEntryModel?>.broadcast();
  final waitlistCalls = <String>[];
  Object? waitlistError;

  @override
  Stream<WaitlistEntryModel?> streamMyWaitlist(String sessionId, String uid) =>
      waitlist.stream;

  @override
  Future<void> joinWaitlist(String sessionId) async {
    if (waitlistError != null) throw waitlistError!;
    waitlistCalls.add('join:$sessionId');
  }

  @override
  Future<void> leaveWaitlist(String sessionId) async {
    if (waitlistError != null) throw waitlistError!;
    waitlistCalls.add('leave:$sessionId');
  }

  final presence = StreamController<Set<String>>.broadcast();
  final checkIns = <(String, bool)>[];
  Object? checkInError;

  @override
  Stream<Set<String>> streamPresentUids(String sessionId, String groupId) =>
      presence.stream;

  @override
  Future<void> checkInPlayer({
    required String sessionId,
    required String userId,
    required bool present,
  }) async {
    if (checkInError != null) throw checkInError!;
    checkIns.add((userId, present));
  }

  @override
  Future<({int refunded, double total})> cancelEvent(String sessionId) async {
    deleted = deleteOnCancel;
    _changes.add(null);
    await Future<void>.delayed(Duration.zero);
    if (cancelError != null) throw cancelError!;
    return (refunded: 2, total: 20.0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGroups implements GroupService {
  final String? role;
  _FakeGroups(this.role);

  @override
  Future<String?> getMemberRole(String groupId, String userId) async => role;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserModel _user({bool superUser = false}) => UserModel(
  uid: 'u1',
  email: 'a@b.pe',
  firstName: 'Ana',
  lastName: 'Perez',
  createdAt: DateTime(2026),
  documentType: 'dni',
  documentNumber: '12345678',
  superUser: superUser,
);

Future<(SessionDetailBloc, List<SessionDetailState>)> _loaded(
  _FakeSessions sessions, {
  String? role = 'owner',
  bool superUser = false,
}) async {
  final bloc = SessionDetailBloc(
    sessionService: sessions,
    groupService: _FakeGroups(role),
    currentUser: _user(superUser: superUser),
  );
  final states = <SessionDetailState>[];
  bloc.stream.listen(states.add);
  bloc.add(const LoadSessionDetail('s1'));
  await bloc.stream.firstWhere((s) => s is SessionDetailLoaded);
  return (bloc, states);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test(
    'success: cancelled state, the not-found stream error is ignored',
    () async {
      final (bloc, states) = await _loaded(_FakeSessions());
      bloc.add(const CancelEvent());
      await _settle();
      expect(states.last, isA<SessionDetailEventCancelled>());
      expect((states.last as SessionDetailEventCancelled).refunded, 2);
      expect(states.whereType<SessionDetailError>(), isEmpty);
      await bloc.close();
    },
  );

  test('failure while the event still exists shows the error', () async {
    final sessions = _FakeSessions()
      ..deleteOnCancel = false
      ..cancelError = Exception(
        'No tienes permiso para gestionar este evento.',
      );
    final (bloc, states) = await _loaded(sessions);
    bloc.add(const CancelEvent());
    await _settle();
    final error = states.whereType<SessionDetailError>().single;
    expect(error.message, 'No tienes permiso para gestionar este evento.');
    expect(error.session, isNotNull);
    await bloc.close();
  });

  test('timeout after the server committed counts as cancelled', () async {
    final sessions = _FakeSessions()..cancelError = Exception('timeout');
    final (bloc, states) = await _loaded(sessions);
    bloc.add(const CancelEvent());
    await _settle();
    expect(states.last, isA<SessionDetailEventCancelled>());
    expect(states.whereType<SessionDetailError>(), isEmpty);
    await bloc.close();
  });

  test(
    'a plain member cannot cancel; a group admin or superUser can manage',
    () async {
      final (member, states) = await _loaded(_FakeSessions(), role: 'member');
      expect((states.last as SessionDetailLoaded).isOwnerOrAdmin, isFalse);
      member.add(const CancelEvent());
      await _settle();
      expect(states.whereType<SessionDetailEventCancelled>(), isEmpty);
      await member.close();

      final (admin, adminStates) = await _loaded(
        _FakeSessions(),
        role: 'admin',
      );
      expect((adminStates.last as SessionDetailLoaded).isOwnerOrAdmin, isTrue);
      await admin.close();

      final (root, rootStates) = await _loaded(
        _FakeSessions(),
        role: null,
        superUser: true,
      );
      expect((rootStates.last as SessionDetailLoaded).isOwnerOrAdmin, isTrue);
      await root.close();
    },
  );

  test('canManageEvent mirrors the server rule', () {
    bool can({String? creator, String? role, bool su = false}) =>
        canManageEvent(
          uid: 'u1',
          creatorId: creator,
          memberRole: role,
          superUser: su,
        );
    expect(can(), isFalse);
    expect(can(role: 'member'), isFalse);
    expect(can(creator: 'other'), isFalse);
    expect(can(creator: ''), isFalse);
    expect(can(creator: 'u1'), isTrue);
    expect(can(role: 'owner'), isTrue);
    expect(can(role: 'admin'), isTrue);
    expect(can(su: true), isTrue);
  });

  test('canCreateEvent needs a superUser who is owner or admin', () {
    expect(canCreateEvent(superUser: true, groupRole: 'owner'), isTrue);
    expect(canCreateEvent(superUser: true, groupRole: 'admin'), isTrue);
    expect(canCreateEvent(superUser: true, groupRole: 'member'), isFalse);
    expect(canCreateEvent(superUser: true, groupRole: null), isFalse);
    expect(canCreateEvent(superUser: false, groupRole: 'owner'), isFalse);
  });

  test('organizer sees who is present and can toggle check-in', () async {
    final sessions = _FakeSessions();
    final (bloc, states) = await _loaded(sessions);
    sessions.presence.add({'p1'});
    await _settle();
    expect((states.last as SessionDetailLoaded).presentUids, {'p1'});

    bloc.add(const TogglePresence('p2', present: true));
    await _settle();
    expect(sessions.checkIns, [('p2', true)]);
    await bloc.close();
  });

  test('a failed check-in shows the error, a member cannot check in', () async {
    final sessions = _FakeSessions()
      ..checkInError = Exception('Este jugador ya no está en el evento.');
    final (bloc, states) = await _loaded(sessions);
    bloc.add(const TogglePresence('p2', present: true));
    await _settle();
    expect(
      states.whereType<SessionDetailError>().single.message,
      'Este jugador ya no está en el evento.',
    );
    // The roster comes straight back: organizer controls stay available.
    final last = states.last as SessionDetailLoaded;
    expect(last.isOwnerOrAdmin, isTrue);
    await bloc.close();

    final memberSessions = _FakeSessions();
    final (member, _) = await _loaded(memberSessions, role: 'member');
    member.add(const TogglePresence('p2', present: true));
    await _settle();
    expect(memberSessions.checkIns, isEmpty);
    await member.close();
  });

  test('a failed attendance stream marks it unavailable', () async {
    final sessions = _FakeSessions();
    final (bloc, states) = await _loaded(sessions);
    sessions.presence.addError(Exception('denied'));
    await _settle();
    expect((states.last as SessionDetailLoaded).presenceAvailable, isFalse);
    sessions.presence.add({'p1'});
    await _settle();
    expect((states.last as SessionDetailLoaded).presenceAvailable, isTrue);
    await bloc.close();
  });

  test('the user\'s waitlist place flows into the page state', () async {
    final sessions = _FakeSessions();
    final (bloc, states) = await _loaded(sessions, role: 'member');
    expect((states.last as SessionDetailLoaded).waitlist, isNull);

    sessions.waitlist.add(const WaitlistEntryModel(status: 'waiting'));
    await _settle();
    expect((states.last as SessionDetailLoaded).waitlist?.status, 'waiting');

    final until = DateTime.now().add(const Duration(minutes: 30));
    sessions.waitlist.add(
      WaitlistEntryModel(status: 'offered', offerExpiresAt: until),
    );
    await _settle();
    final entry = (states.last as SessionDetailLoaded).waitlist!;
    expect(entry.isHolding(DateTime.now()), isTrue);

    sessions.waitlist.add(null); // joined or left
    await _settle();
    expect((states.last as SessionDetailLoaded).waitlist, isNull);
    await bloc.close();
  });

  test(
    'join and leave the waitlist call the server; errors keep the page',
    () async {
      final sessions = _FakeSessions();
      final (bloc, states) = await _loaded(sessions, role: 'member');
      bloc.add(const JoinWaitlist());
      bloc.add(const LeaveWaitlist());
      await _settle();
      expect(sessions.waitlistCalls, ['join:s1', 'leave:s1']);

      sessions.waitlistError = Exception('Aún hay cupos: únete directamente.');
      bloc.add(const JoinWaitlist());
      await _settle();
      expect(
        states.whereType<SessionDetailError>().last.message,
        'Aún hay cupos: únete directamente.',
      );
      expect(states.last, isA<SessionDetailLoaded>());
      // the page keeps showing the newest waitlist data after the error
      sessions.waitlistError = null;
      sessions.waitlist.add(const WaitlistEntryModel(status: 'waiting'));
      await _settle();
      expect((states.last as SessionDetailLoaded).waitlist?.status, 'waiting');
      await bloc.close();
    },
  );

  test('an offer holds a seat only until it expires', () {
    final now = DateTime(2026, 11, 26, 12);
    final live = WaitlistEntryModel(
      status: 'offered',
      offerExpiresAt: now.add(const Duration(minutes: 1)),
    );
    expect(live.isHolding(now), isTrue);
    expect(live.isHolding(now.add(const Duration(minutes: 2))), isFalse);
    expect(const WaitlistEntryModel(status: 'waiting').isHolding(now), isFalse);
    expect(
      WaitlistEntryModel.fromMap({'status': 'waiting'}).offerExpiresAt,
      isNull,
    );
  });
}
