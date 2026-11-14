import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:proplay/utils/document.dart';

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
  final DocumentType documentType;
  final String documentNumber;
  final String? groupCode;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.documentType,
    required this.documentNumber,
    this.groupCode,
  });

  @override
  List<Object?> get props => [
    email,
    password,
    firstName,
    lastName,
    documentType,
    documentNumber,
    groupCode,
  ];
}

class AuthGoogleSignInRequested extends AuthEvent {
  final String? groupCode;

  /// Required for new accounts (registration screen). Null on the login screen.
  final DocumentType? documentType;
  final String? documentNumber;

  const AuthGoogleSignInRequested({
    this.groupCode,
    this.documentType,
    this.documentNumber,
  });

  @override
  List<Object?> get props => [groupCode, documentType, documentNumber];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthRefreshUserRequested extends AuthEvent {
  const AuthRefreshUserRequested();
}

class AuthPasswordResetRequested extends AuthEvent {
  final String email;

  const AuthPasswordResetRequested({required this.email});

  @override
  List<Object?> get props => [email];
}
