import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/bloc/validate_ticket/validate_ticket_bloc.dart';
import 'package:proplay/bloc/validate_ticket/validate_ticket_event.dart';
import 'package:proplay/bloc/validate_ticket/validate_ticket_state.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/ticket_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/services/ticket_service.dart';
import 'package:proplay/utils/ticket_url_builder.dart';

TicketModel _ticket() => TicketModel(
  id: 's1_p1',
  sessionId: 's1',
  groupId: 'g1',
  userId: 'p1',
  validationToken: 'tok',
  status: 'valid',
  createdAt: DateTime(2026),
  eventTitle: 'Pichanga',
  eventDate: DateTime(2030),
  eventEndDate: DateTime(2030),
  sport: 'fútbol',
  userFirstName: 'Ana',
  userLastName: 'Perez',
  userDocumentType: 'dni',
  userDocumentNumber: '12345678',
);

class _DeniedTickets implements TicketService {
  @override
  Future<TicketModel?> getTicketByToken(
    String token, {
    String? ticketId,
  }) async => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'permission-denied',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tickets implements TicketService {
  @override
  Future<TicketModel?> getTicketByToken(
    String token, {
    String? ticketId,
  }) async => _ticket();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Groups implements GroupService {
  final String? role;
  final bool fail;
  _Groups(this.role, {this.fail = false});

  @override
  Future<String?> getMemberRole(String groupId, String userId) async {
    if (fail) throw Exception('network');
    return role;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sessions implements SessionService {
  final String? creatorId;
  _Sessions(this.creatorId);

  @override
  Stream<SessionModel> streamSession(String sessionId) => Stream.value(
    SessionModel(
      id: 's1',
      templateId: 't',
      groupId: 'g1',
      title: 'x',
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
      creatorId: creatorId,
    ),
  );

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

Future<bool> _canValidate({
  String? role,
  String? creatorId,
  bool superUser = false,
}) async {
  final bloc = ValidateTicketBloc(
    ticketService: _Tickets(),
    groupService: _Groups(role),
    sessionService: _Sessions(creatorId),
    currentUser: _user(superUser: superUser),
  );
  bloc.add(const LoadTicketByToken('tok'));
  final state = await bloc.stream.firstWhere((s) => s is ValidateTicketLoaded);
  await bloc.close();
  return (state as ValidateTicketLoaded).isOwnerOrAdmin;
}

void main() {
  test(
    'same rule as the event page: creator, owner/admin or superUser',
    () async {
      expect(await _canValidate(), isFalse);
      expect(await _canValidate(role: 'member'), isFalse);
      expect(await _canValidate(creatorId: 'other'), isFalse);
      expect(await _canValidate(creatorId: 'u1'), isTrue);
      expect(await _canValidate(role: 'owner'), isTrue);
      expect(await _canValidate(role: 'admin'), isTrue);
      expect(await _canValidate(superUser: true), isTrue);
    },
  );

  test('a failed lookup asks to retry; a real allow still wins', () async {
    ValidateTicketBloc build({required bool failGroups, String? role}) =>
        ValidateTicketBloc(
          ticketService: _Tickets(),
          groupService: _Groups(role, fail: failGroups),
          sessionService: _Sessions(null),
          currentUser: _user(),
        );

    final failing = build(failGroups: true)
      ..add(const LoadTicketByToken('tok'));
    final state = await failing.stream.firstWhere(
      (s) => s is ValidateTicketError || s is ValidateTicketLoaded,
    );
    expect(state, isA<ValidateTicketError>());
    expect((state as ValidateTicketError).message, contains('Inténtalo'));
    await failing.close();

    // Role lookup failed but the creator check still allows: no error.
    final creator = ValidateTicketBloc(
      ticketService: _Tickets(),
      groupService: _Groups(null, fail: true),
      sessionService: _Sessions('u1'),
      currentUser: _user(),
    )..add(const LoadTicketByToken('tok'));
    final ok = await creator.stream.firstWhere(
      (s) => s is ValidateTicketError || s is ValidateTicketLoaded,
    );
    expect((ok as ValidateTicketLoaded).isOwnerOrAdmin, isTrue);
    await creator.close();
  });

  test(
    'a denied read (missing, cancelled or old QR) shows one message',
    () async {
      final bloc = ValidateTicketBloc(
        ticketService: _DeniedTickets(),
        groupService: _Groups('owner'),
        sessionService: _Sessions(null),
        currentUser: _user(),
      )..add(const LoadTicketByToken('tok', ticketId: 's1_p1'));
      final state = await bloc.stream.firstWhere(
        (s) => s is ValidateTicketError,
      );
      expect((state as ValidateTicketError).message, contains('no existe'));
      expect(state.message, contains('QR es antiguo'));
      await bloc.close();
    },
  );

  test('the QR url carries the ticket id and the token', () {
    final uri = Uri.parse(TicketUrlBuilder.buildValidationUrl('s1_p1', 'a b'));
    expect(uri.path, '/validate-ticket');
    expect(uri.queryParameters, {'id': 's1_p1', 'token': 'a b'});
  });
}
