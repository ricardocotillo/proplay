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
    if (currentState is! GroupDetailLoaded && currentState is! GroupDetailRoleUpdated) return;

    final currentMembers = currentState is GroupDetailLoaded
        ? currentState.members
        : (currentState as GroupDetailRoleUpdated).members;
    final currentUserRole = currentState is GroupDetailLoaded
        ? currentState.currentUserRole
        : (currentState as GroupDetailRoleUpdated).currentUserRole;

    try {
      // Toggle between 'admin' and 'member'
      final newRole = event.currentRole == 'admin' ? 'member' : 'admin';

      await groupService.updateMemberRole(
        event.groupId,
        event.userId,
        newRole,
      );

      // Update the specific member in the list
      final updatedMembers = currentMembers.map((member) {
        if (member.userId == event.userId) {
          return GroupMemberModel(
            userId: member.userId,
            user: member.user,
            role: newRole,
          );
        }
        return member;
      }).toList();

      emit(GroupDetailRoleUpdated(
        members: updatedMembers,
        currentUserRole: currentUserRole,
      ));
    } catch (e) {
      emit(GroupDetailError(e.toString()));
      // Re-emit previous state after error
      emit(GroupDetailLoaded(
        members: currentMembers,
        currentUserRole: currentUserRole,
      ));
    }
  }
}
