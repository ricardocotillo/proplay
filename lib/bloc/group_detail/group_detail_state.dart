import 'package:equatable/equatable.dart';
import 'package:proplay/models/group_member_model.dart';

abstract class GroupDetailState extends Equatable {
  const GroupDetailState();

  @override
  List<Object?> get props => [];
}

class GroupDetailInitial extends GroupDetailState {}

class GroupDetailLoading extends GroupDetailState {}

class GroupDetailLoaded extends GroupDetailState {
  final List<GroupMemberModel> members;
  final String? currentUserRole;

  const GroupDetailLoaded({
    required this.members,
    this.currentUserRole,
  });

  @override
  List<Object?> get props => [members, currentUserRole];
}

class GroupDetailError extends GroupDetailState {
  final String message;

  const GroupDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

class GroupDetailRoleUpdated extends GroupDetailState {
  final List<GroupMemberModel> members;
  final String? currentUserRole;

  const GroupDetailRoleUpdated({
    required this.members,
    required this.currentUserRole,
  });

  @override
  List<Object?> get props => [members, currentUserRole];
}
