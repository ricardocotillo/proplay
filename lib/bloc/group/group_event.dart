import 'package:equatable/equatable.dart';

abstract class GroupEvent extends Equatable {
  const GroupEvent();

  @override
  List<Object?> get props => [];
}

class GroupCreateRequested extends GroupEvent {
  final String name;
  final List<String> sports;
  final String createdBy;

  const GroupCreateRequested({
    required this.name,
    required this.sports,
    required this.createdBy,
  });

  @override
  List<Object?> get props => [name, sports, createdBy];
}

class GroupJoinRequested extends GroupEvent {
  final String code;
  final String userId;

  const GroupJoinRequested({
    required this.code,
    required this.userId,
  });

  @override
  List<Object?> get props => [code, userId];
}

class GroupLoadUserGroups extends GroupEvent {
  final String userId;

  const GroupLoadUserGroups(this.userId);

  @override
  List<Object?> get props => [userId];
}

class GroupDeleteRequested extends GroupEvent {
  final String groupId;

  const GroupDeleteRequested(this.groupId);

  @override
  List<Object?> get props => [groupId];
}
