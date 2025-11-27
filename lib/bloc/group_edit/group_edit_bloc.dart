import 'dart:io';

import 'package:bloc/bloc.dart' as bloc;
import 'package:equatable/equatable.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/storage_service.dart';

part 'group_edit_event.dart';
part 'group_edit_state.dart';

class GroupEditBloc extends bloc.Bloc<GroupEditEvent, GroupEditState> {
  final GroupService _groupService;
  final StorageService _storageService;

  GroupEditBloc({
    required GroupService groupService,
    StorageService? storageService,
  })  : _groupService = groupService,
        _storageService = storageService ?? StorageService(),
        super(GroupEditInitial()) {
    on<GroupEditSubmitted>(_onGroupEditSubmitted);
    on<GroupDeleted>(_onGroupDeleted);
  }

  void _onGroupEditSubmitted(
    GroupEditSubmitted event,
    bloc.Emitter<GroupEditState> emit,
  ) async {
    emit(GroupEditInProgress());
    try {
      String? profileImageUrl;

      // Upload profile image if provided
      if (event.profileImage != null && event.profileImage is File) {
        profileImageUrl = await _storageService.uploadGroupImage(
          event.groupId,
          event.profileImage as File,
        );
      }

      final updateData = {
        'name': event.name,
        'sport': event.sport,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      };

      await _groupService.updateGroup(event.groupId, updateData);
      emit(const GroupEditSuccess('Group updated successfully'));
    } catch (e) {
      emit(GroupEditFailure(e.toString()));
    }
  }

  void _onGroupDeleted(
    GroupDeleted event,
    bloc.Emitter<GroupEditState> emit,
  ) async {
    emit(GroupEditInProgress());
    try {
      await _groupService.deleteGroup(event.groupId);
      emit(const GroupEditSuccess('Group deleted successfully'));
    } catch (e) {
      emit(GroupEditFailure(e.toString()));
    }
  }
}
