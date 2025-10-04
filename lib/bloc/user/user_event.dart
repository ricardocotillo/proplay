import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

class UserUpdateRequested extends UserEvent {
  final String uid;
  final String firstName;
  final String lastName;

  const UserUpdateRequested({
    required this.uid,
    required this.firstName,
    required this.lastName,
  });

  @override
  List<Object?> get props => [uid, firstName, lastName];
}

class UserProfileImageUpdateRequested extends UserEvent {
  final String uid;
  final String imageUrl;

  const UserProfileImageUpdateRequested({
    required this.uid,
    required this.imageUrl,
  });

  @override
  List<Object?> get props => [uid, imageUrl];
}
