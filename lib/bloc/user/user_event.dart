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

class UserMatchInfoUpdateRequested extends UserEvent {
  final String uid;
  final String? gender;
  final int? age;
  final String? location;
  final bool? profileCompletionDismissed;

  const UserMatchInfoUpdateRequested({
    required this.uid,
    required this.gender,
    required this.age,
    required this.location,
    this.profileCompletionDismissed,
  });

  @override
  List<Object?> get props => [
    uid,
    gender,
    age,
    location,
    profileCompletionDismissed,
  ];
}

class UserProfileCompletionDismissedRequested extends UserEvent {
  final String uid;

  const UserProfileCompletionDismissedRequested({required this.uid});

  @override
  List<Object?> get props => [uid];
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
