import 'package:equatable/equatable.dart';

abstract class UserState extends Equatable {
  const UserState();

  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserUpdateSuccess extends UserState {
  final String message;

  const UserUpdateSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class UserUpdateFailure extends UserState {
  final String error;

  const UserUpdateFailure(this.error);

  @override
  List<Object?> get props => [error];
}
