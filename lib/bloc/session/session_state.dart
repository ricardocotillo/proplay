part of 'session_bloc.dart';

abstract class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object> get props => [];
}

class SessionInitial extends SessionState {}

class SessionLoading extends SessionState {}

class SessionLoaded extends SessionState {
  final List<SessionModel> sessions;
  final String? currentUserRole;

  const SessionLoaded(this.sessions, {this.currentUserRole});

  @override
  List<Object> get props => [sessions, currentUserRole ?? ''];
}

class SessionError extends SessionState {
  final String message;

  const SessionError(this.message);

  @override
  List<Object> get props => [message];
}