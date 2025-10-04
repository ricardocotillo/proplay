import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_state.dart';
import 'package:proplay/models/user_model.dart';

/// Helper class to access current user from anywhere in the app
class AuthHelper {
  /// Get current user model from context
  /// Returns null if user is not authenticated
  static UserModel? getCurrentUser(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.userModel;
    }
    return null;
  }

  /// Watch current user model with context
  /// This will rebuild the widget when auth state changes
  static UserModel? watchCurrentUser(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.userModel;
    }
    return null;
  }

  /// Check if user is authenticated
  static bool isAuthenticated(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated;
  }
}

/// Extension on BuildContext for easier access to current user
extension AuthContextExtension on BuildContext {
  /// Get current user (read once, won't rebuild)
  UserModel? get currentUser {
    final authState = read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.userModel;
    }
    return null;
  }

  /// Watch current user (will rebuild when auth state changes)
  UserModel? get watchUser {
    final authState = watch<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.userModel;
    }
    return null;
  }

  /// Check if user is authenticated
  bool get isAuthenticated {
    final authState = read<AuthBloc>().state;
    return authState is AuthAuthenticated;
  }
}
