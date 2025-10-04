import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/bloc/group/group_event.dart';
import 'package:proplay/bloc/group/group_state.dart';

class GroupBloc extends Bloc<GroupEvent, GroupState> {
  final GroupService _groupService;

  GroupBloc({required GroupService groupService})
      : _groupService = groupService,
        super(GroupInitial()) {
    on<GroupCreateRequested>(_onGroupCreateRequested);
    on<GroupJoinRequested>(_onGroupJoinRequested);
    on<GroupLoadUserGroups>(_onGroupLoadUserGroups);
  }

  Future<void> _onGroupCreateRequested(
    GroupCreateRequested event,
    Emitter<GroupState> emit,
  ) async {
    emit(GroupLoading());
    try {
      final group = await _groupService.createGroup(
        name: event.name,
        sports: event.sports,
        createdBy: event.createdBy,
      );
      emit(GroupCreateSuccess(group));
    } catch (e) {
      emit(GroupError(e.toString()));
    }
  }

  Future<void> _onGroupJoinRequested(
    GroupJoinRequested event,
    Emitter<GroupState> emit,
  ) async {
    emit(GroupLoading());
    try {
      await _groupService.joinGroup(event.code, event.userId);
      emit(const GroupJoinSuccess('Successfully joined group'));
    } catch (e) {
      emit(GroupError(e.toString()));
    }
  }

  Future<void> _onGroupLoadUserGroups(
    GroupLoadUserGroups event,
    Emitter<GroupState> emit,
  ) async {
    emit(GroupLoading());
    try {
      final groups = await _groupService.getUserGroups(event.userId);
      emit(GroupLoaded(groups));
    } catch (e) {
      emit(GroupError(e.toString()));
    }
  }
}
