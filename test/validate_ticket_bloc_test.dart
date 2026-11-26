import 'dart:async';

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

class _Tickets implements TicketService {
  @override
  Future<TicketModel?> getTicketByToken(String token) async => _ticket();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Groups implements GroupService {
  final String? role;
  _Groups(this.role);

  @override
  Future<String?> getMemberRole(String groupId, String userId) async => role;

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
}
