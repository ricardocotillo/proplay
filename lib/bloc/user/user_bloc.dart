import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/bloc/user/user_event.dart';
import 'package:proplay/bloc/user/user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserService _userService;

  UserBloc({required UserService userService})
      : _userService = userService,
        super(UserInitial()) {
    on<UserUpdateRequested>(_onUserUpdateRequested);
    on<UserProfileImageUpdateRequested>(_onUserProfileImageUpdateRequested);
  }

  Future<void> _onUserUpdateRequested(
    UserUpdateRequested event,
    Emitter<UserState> emit,
  ) async {
    emit(UserLoading());
    try {
      await _userService.updateUser(event.uid, {
        'firstName': event.firstName,
        'lastName': event.lastName,
      });
      emit(const UserUpdateSuccess('Profile updated successfully'));
    } catch (e) {
      emit(UserUpdateFailure(e.toString()));
    }
  }

  Future<void> _onUserProfileImageUpdateRequested(
    UserProfileImageUpdateRequested event,
    Emitter<UserState> emit,
  ) async {
    emit(UserLoading());
    try {
      await _userService.updateProfileImage(event.uid, event.imageUrl);
      emit(const UserUpdateSuccess('Profile image updated successfully'));
    } catch (e) {
      emit(UserUpdateFailure(e.toString()));
    }
  }
}
