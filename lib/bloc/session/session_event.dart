part of 'session_bloc.dart';

abstract class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object> get props => [];
}

class LoadSessions extends SessionEvent {
  final String groupId;

  const LoadSessions(this.groupId);

  @override
  List<Object> get props => [groupId];
}

class LoadAllUserSessions extends SessionEvent {
  final List<String> groupIds;

  const LoadAllUserSessions(this.groupIds);

  @override
  List<Object> get props => [groupIds];
}

class DeleteSession extends SessionEvent {
  final String sessionId;

  const DeleteSession(this.sessionId);

  @override
  List<Object> get props => [sessionId];
}
