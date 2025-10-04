
part of 'group_edit_bloc.dart';

abstract class GroupEditState extends Equatable {
  const GroupEditState();

  @override
  List<Object> get props => [];
}

class GroupEditInitial extends GroupEditState {}

class GroupEditInProgress extends GroupEditState {}

class GroupEditSuccess extends GroupEditState {
  final String message;

  const GroupEditSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class GroupEditFailure extends GroupEditState {
  final String error;

  const GroupEditFailure(this.error);

  @override
  List<Object> get props => [error];
}
