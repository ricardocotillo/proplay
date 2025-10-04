
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:proplay/services/group_service.dart';

part 'group_edit_event.dart';
part 'group_edit_state.dart';

class GroupEditBloc extends Bloc<GroupEditEvent, GroupEditState> {
  final GroupService _groupService;

  GroupEditBloc({required GroupService groupService}) : _groupService = groupService, super(GroupEditInitial()) {
    on<GroupEditSubmitted>(_onGroupEditSubmitted);
    on<GroupDeleted>(_onGroupDeleted);
  }

  void _onGroupEditSubmitted(GroupEditSubmitted event, Emitter<GroupEditState> emit) async {
    emit(GroupEditInProgress());
    try {
      await _groupService.updateGroup(event.groupId, {
        'name': event.name,
        'sports': event.sports,
      });
      emit(const GroupEditSuccess('Group updated successfully'));
    } catch (e) {
      emit(GroupEditFailure(e.toString()));
    }
  }

  void _onGroupDeleted(GroupDeleted event, Emitter<GroupEditState> emit) async {
    emit(GroupEditInProgress());
    try {
      await _groupService.deleteGroup(event.groupId);
      emit(const GroupEditSuccess('Group deleted successfully'));
    } catch (e) {
      emit(GroupEditFailure(e.toString()));
    }
  }
}
