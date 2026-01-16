import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:proplay/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User firebaseUser;
  final UserModel userModel;

  const AuthAuthenticated({
    required this.firebaseUser,
    required this.userModel,
  });

  @override
  List<Object?> get props => [firebaseUser, userModel];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthSuccessWithInfo extends AuthState {
  final String message;
  final User firebaseUser;
  final UserModel userModel;

  const AuthSuccessWithInfo({
    required this.message,
    required this.firebaseUser,
    required this.userModel,
  });

  @override
  List<Object?> get props => [message, firebaseUser, userModel];
}

class AuthPasswordResetEmailSent extends AuthState {
  final String message;

  const AuthPasswordResetEmailSent(this.message);

  @override
  List<Object?> get props => [message];
}
