part of 'create_session_bloc.dart';

abstract class CreateSessionState extends Equatable {
  const CreateSessionState();

  @override
  List<Object> get props => [];
}

class CreateSessionInitial extends CreateSessionState {}

class CreateSessionLoading extends CreateSessionState {}

class SessionCreationSuccess extends CreateSessionState {}

class SessionCreationFailure extends CreateSessionState {
  final String message;

  const SessionCreationFailure(this.message);

  @override
  List<Object> get props => [message];
}
