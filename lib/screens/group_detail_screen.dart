import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/bloc/group_detail/group_detail_bloc.dart';
import 'package:proplay/bloc/group_detail/group_detail_event.dart';
import 'package:proplay/bloc/group_detail/group_detail_state.dart';
import 'package:proplay/models/group_model.dart';
import 'package:proplay/models/group_member_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/utils/auth_helper.dart';

class GroupDetailScreen extends StatelessWidget {
  final GroupModel group;

  const GroupDetailScreen({super.key, required this.group});

  void _showRoleChangeDialog(
    BuildContext context,
    GroupMemberModel member,
    String groupId,
  ) {
    final newRole = member.role == 'admin' ? 'member' : 'admin';
    final newRoleLabel = newRole == 'admin' ? 'administrador' : 'miembro';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cambiar rol'),
        content: Text(
          '¿Cambiar el rol de ${member.user.fullName} a $newRoleLabel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<GroupDetailBloc>().add(
                GroupDetailToggleMemberRole(
                  groupId: groupId,
                  userId: member.userId,
                  currentRole: member.role,
                ),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.currentUser;

    return BlocProvider(
      create: (context) => GroupDetailBloc(
        groupService: GroupService(userService: UserService()),
        userService: UserService(),
        currentUserId: currentUser?.uid ?? '',
      )..add(GroupDetailLoadMembers(group.id)),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: Text(group.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/group/${group.id}/edit'),
            ),
          ],
        ),
        body: BlocConsumer<GroupDetailBloc, GroupDetailState>(
          listener: (context, state) {
            if (state is GroupDetailError) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          builder: (context, state) {
            if (state is GroupDetailLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is GroupDetailLoaded ||
                state is GroupDetailUpdatingRole) {
              final members = state is GroupDetailLoaded
                  ? state.members
                  : (state as GroupDetailUpdatingRole).members;
              final currentUserRole = state is GroupDetailLoaded
                  ? state.currentUserRole
                  : (state as GroupDetailUpdatingRole).currentUserRole;
              final isOwner = currentUserRole == 'owner';

              return ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final isCurrentUser = member.userId == currentUser?.uid;
                  final canChangeRole =
                      isOwner && !isCurrentUser && member.role != 'owner';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: member.user.profileImageUrl != null
                          ? NetworkImage(member.user.profileImageUrl!)
                          : null,
                      child: member.user.profileImageUrl == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(member.user.fullName),
                    subtitle: Text(member.roleLabel),
                    onLongPress: canChangeRole
                        ? () => _showRoleChangeDialog(context, member, group.id)
                        : null,
                  );
                },
              );
            }

            return const Center(child: Text('Error cargando miembros'));
          },
        ),
      ),
    );
  }
}
