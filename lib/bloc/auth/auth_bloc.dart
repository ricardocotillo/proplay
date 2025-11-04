import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/services/auth_service.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/bloc/auth/auth_state.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final UserService _userService;
  final GroupService _groupService;
  StreamSubscription<User?>? _authSubscription;

  AuthBloc({
    required AuthService authService,
    required UserService userService,
    required GroupService groupService,
  }) : _authService = authService,
       _userService = userService,
       _groupService = groupService,
       super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthGoogleSignInRequested>(_onAuthGoogleSignInRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthUserChanged>(_onAuthUserChanged);

    // Start listening to auth state changes
    _authSubscription = _authService.authStateChanges.listen(
      (user) => add(AuthUserChanged(user)),
    );
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = _authService.currentUser;
    if (user != null) {
      final userModel = await _userService.getUser(user.uid);
      if (userModel != null) {
        emit(AuthAuthenticated(firebaseUser: user, userModel: userModel));
      } else {
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthUserChanged(
    AuthUserChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (event.user != null) {
      final userModel = await _userService.getUser(event.user!.uid);
      if (userModel != null) {
        emit(
          AuthAuthenticated(firebaseUser: event.user!, userModel: userModel),
        );
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
        emit(
          AuthAuthenticated(
            firebaseUser: userCredential.user!,
            userModel: userModel,
          ),
        );
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

      if (event.groupCode != null && event.groupCode!.isNotEmpty) {
        try {
          await _groupService.joinGroup(event.groupCode!, user.uid);
        } catch (e) {
          // Group not found, but registration is successful
          emit(
            AuthSuccessWithInfo(
              message:
                  'Usuário registrado com sucesso, mas o código do grupo não foi encontrado.',
              firebaseUser: userCredential.user!,
              userModel: user,
            ),
          );
          return;
        }
      }

      emit(
        AuthAuthenticated(firebaseUser: userCredential.user!, userModel: user),
      );
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final userCredential = await _authService.signInWithGoogle();
      final firebaseUser = userCredential.user!;

      // Check if user already exists in Firestore
      var userModel = await _userService.getUser(firebaseUser.uid);

      // If user doesn't exist, create a new user document
      if (userModel == null) {
        // Extract first and last name from Google display name
        final displayName = firebaseUser.displayName ?? '';
        final nameParts = displayName.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName = nameParts.length > 1
            ? nameParts.sublist(1).join(' ')
            : '';

        userModel = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email!,
          firstName: firstName,
          lastName: lastName,
          profileImageUrl: firebaseUser.photoURL,
          createdAt: DateTime.now(),
        );

        await _userService.createUser(userModel);

        // Join group if group code is provided
        if (event.groupCode != null && event.groupCode!.isNotEmpty) {
          try {
            await _groupService.joinGroup(event.groupCode!, userModel.uid);
          } catch (e) {
            // Group not found, but registration is successful
            emit(
              AuthSuccessWithInfo(
                message:
                    'Usuário registrado com sucesso, mas o código do grupo não foi encontrado.',
                firebaseUser: firebaseUser,
                userModel: userModel,
              ),
            );
            return;
          }
        }
      }

      emit(AuthAuthenticated(firebaseUser: firebaseUser, userModel: userModel));
    } catch (e) {
      print(e);
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
