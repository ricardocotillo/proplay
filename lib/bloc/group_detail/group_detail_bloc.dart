import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/group_detail/group_detail_event.dart';
import 'package:proplay/bloc/group_detail/group_detail_state.dart';
import 'package:proplay/models/group_member_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/user_service.dart';

class GroupDetailBloc extends Bloc<GroupDetailEvent, GroupDetailState> {
  final GroupService groupService;
  final UserService userService;
  final String currentUserId;

  GroupDetailBloc({
    required this.groupService,
    required this.userService,
    required this.currentUserId,
  }) : super(GroupDetailInitial()) {
    on<GroupDetailLoadMembers>(_onLoadMembers);
    on<GroupDetailToggleMemberRole>(_onToggleMemberRole);
  }

  Future<void> _onLoadMembers(
    GroupDetailLoadMembers event,
    Emitter<GroupDetailState> emit,
  ) async {
    emit(GroupDetailLoading());
    try {
      final membersData = await groupService.getGroupMembers(event.groupId);
      final members = <GroupMemberModel>[];

      for (var memberData in membersData) {
        final user = await userService.getUser(memberData['userId']);
        if (user != null) {
          members.add(GroupMemberModel.fromMap(memberData, user));
        }
      }

      final currentUserRole =
          await groupService.getMemberRole(event.groupId, currentUserId);

      emit(GroupDetailLoaded(
        members: members,
        currentUserRole: currentUserRole,
      ));
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> _onToggleMemberRole(
    GroupDetailToggleMemberRole event,
    Emitter<GroupDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GroupDetailLoaded) return;

    emit(GroupDetailUpdatingRole(
      members: currentState.members,
      currentUserRole: currentState.currentUserRole,
      updatingUserId: event.userId,
    ));

    try {
      // Toggle between 'admin' and 'member'
      final newRole = event.currentRole == 'admin' ? 'member' : 'admin';

      await groupService.updateMemberRole(
        event.groupId,
        event.userId,
        newRole,
      );

      // Reload members to get updated data
      add(GroupDetailLoadMembers(event.groupId));
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }
}
