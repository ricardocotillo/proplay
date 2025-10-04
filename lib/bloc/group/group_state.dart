import 'package:equatable/equatable.dart';
import 'package:proplay/models/group_model.dart';

abstract class GroupState extends Equatable {
  const GroupState();

  @override
  List<Object?> get props => [];
}

class GroupInitial extends GroupState {}

class GroupLoading extends GroupState {}

class GroupCreateSuccess extends GroupState {
  final GroupModel group;

  const GroupCreateSuccess(this.group);

  @override
  List<Object?> get props => [group];
}

class GroupJoinSuccess extends GroupState {
  final String message;

  const GroupJoinSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class GroupLoaded extends GroupState {
  final List<GroupModel> groups;

  const GroupLoaded(this.groups);

  @override
  List<Object?> get props => [groups];
}

class GroupError extends GroupState {
  final String message;

  const GroupError(this.message);

  @override
  List<Object?> get props => [message];
}
