import 'package:equatable/equatable.dart';

abstract class GroupDetailEvent extends Equatable {
  const GroupDetailEvent();

  @override
  List<Object?> get props => [];
}

class GroupDetailLoadMembers extends GroupDetailEvent {
  final String groupId;

  const GroupDetailLoadMembers(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

class GroupDetailToggleMemberRole extends GroupDetailEvent {
  final String groupId;
  final String userId;
  final String currentRole;

  const GroupDetailToggleMemberRole({
    required this.groupId,
    required this.userId,
    required this.currentRole,
  });

  @override
  List<Object?> get props => [groupId, userId, currentRole];
}

class GroupDetailRemoveMember extends GroupDetailEvent {
  final String groupId;
  final String userId;

  const GroupDetailRemoveMember({
    required this.groupId,
    required this.userId,
  });

  @override
  List<Object?> get props => [groupId, userId];
}
