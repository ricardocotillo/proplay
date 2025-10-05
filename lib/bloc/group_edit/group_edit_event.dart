
part of 'group_edit_bloc.dart';

abstract class GroupEditEvent extends Equatable {
  const GroupEditEvent();

  @override
  List<Object> get props => [];
}

class GroupEditSubmitted extends GroupEditEvent {
  final String groupId;
  final String name;
  final List<String> sports;
  final dynamic profileImage;

  const GroupEditSubmitted({
    required this.groupId,
    required this.name,
    required this.sports,
    this.profileImage,
  });

  @override
  List<Object> get props => [groupId, name, sports];
}

class GroupDeleted extends GroupEditEvent {
  final String groupId;

  const GroupDeleted(this.groupId);

  @override
  List<Object> get props => [groupId];
}
