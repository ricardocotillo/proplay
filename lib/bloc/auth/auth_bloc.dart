import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/services/auth_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/bloc/auth/auth_state.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final UserService _userService;
  StreamSubscription<User?>? _authSubscription;

  AuthBloc({
    required AuthService authService,
    required UserService userService,
  })  : _authService = authService,
        _userService = userService,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);

    // Start listening to auth state changes
    _authSubscription = _authService.authStateChanges.listen((user) async {
      if (user != null) {
        final userModel = await _userService.getUser(user.uid);
        if (userModel != null) {
          emit(AuthAuthenticated(
            firebaseUser: user,
            userModel: userModel,
          ));
        } else {
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    });
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = _authService.currentUser;
    if (user != null) {
      final userModel = await _userService.getUser(user.uid);
      if (userModel != null) {
        emit(AuthAuthenticated(
          firebaseUser: user,
          userModel: userModel,
        ));
      } else {
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final userCredential = await _authService.signInWithEmailAndPassword(
        event.email,
        event.password,
      );

      // Get user model from Firestore
      final userModel = await _userService.getUser(userCredential.user!.uid);
      if (userModel != null) {
        emit(AuthAuthenticated(
          firebaseUser: userCredential.user!,
          userModel: userModel,
        ));
      } else {
        emit(AuthError('User data not found'));
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final userCredential = await _authService.registerWithEmailAndPassword(
        event.email,
        event.password,
      );

      // Create user document in Firestore
      final user = UserModel(
        uid: userCredential.user!.uid,
        email: event.email,
        firstName: event.firstName,
        lastName: event.lastName,
        profileImageUrl: null,
        createdAt: DateTime.now(),
      );

      await _userService.createUser(user);

      emit(AuthAuthenticated(
        firebaseUser: userCredential.user!,
        userModel: user,
      ));
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signOut();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
