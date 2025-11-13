import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthUserChanged extends AuthEvent {
  final User? user;

  const AuthUserChanged(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String? groupCode;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    this.groupCode,
  });

  @override
  List<Object?> get props => [email, password, firstName, lastName, groupCode];
}

class AuthGoogleSignInRequested extends AuthEvent {
  final String? groupCode;

  const AuthGoogleSignInRequested({this.groupCode});

  @override
  List<Object?> get props => [groupCode];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthRefreshUserRequested extends AuthEvent {
  const AuthRefreshUserRequested();
}
