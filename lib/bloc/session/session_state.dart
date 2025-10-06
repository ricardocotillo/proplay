
import 'package:equatable/equatable.dart';

abstract class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object> get props => [];
}

class SessionInitial extends SessionState {}

class SessionCreationLoading extends SessionState {}

class SessionCreationSuccess extends SessionState {}

class SessionCreationFailure extends SessionState {
  final String message;

  const SessionCreationFailure(this.message);

  @override
  List<Object> get props => [message];
}
