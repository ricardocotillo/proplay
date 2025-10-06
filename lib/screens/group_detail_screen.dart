import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:proplay/screens/groups_sessions_screen.dart';

class GroupDetailScreen extends StatelessWidget {
  final GroupModel group;

  const GroupDetailScreen({super.key, required this.group});

  void _showMemberOptions(
    BuildContext context,
    GroupMemberModel member,
    String groupId,
  ) {
    final isAdmin = member.role == 'admin';
    final roleActionLabel = isAdmin
        ? 'Remover como administrador'
        : 'Designar como administrador';

    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isAdmin ? Icons.person : Icons.admin_panel_settings,
              ),
              title: Text(roleActionLabel),
              onTap: () {
                context.read<GroupDetailBloc>().add(
                  GroupDetailToggleMemberRole(
                    groupId: groupId,
                    userId: member.userId,
                    currentRole: member.role,
                  ),
                );
                Navigator.pop(bottomSheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text(
                'Remover usuario',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                context.read<GroupDetailBloc>().add(
                  GroupDetailRemoveMember(
                    groupId: groupId,
                    userId: member.userId,
                  ),
                );
                Navigator.pop(bottomSheetContext);
              },
            ),
          ],
        ),
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
          title: InkWell(
            onTap: () => context.push('/group/${group.id}/info'),
            child: Text(group.name),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GroupsSessionsScreen(),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: group.code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Código copiado al portapapeles'),
                    ),
                  );
                }
              },
              child: Text(group.code),
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
                state is GroupDetailRoleUpdated ||
                state is GroupDetailMemberRemoved) {
              final members = state is GroupDetailLoaded
                  ? state.members
                  : state is GroupDetailRoleUpdated
                  ? state.members
                  : (state as GroupDetailMemberRemoved).members;
              final currentUserRole = state is GroupDetailLoaded
                  ? state.currentUserRole
                  : state is GroupDetailRoleUpdated
                  ? state.currentUserRole
                  : (state as GroupDetailMemberRemoved).currentUserRole;
              final isOwner = currentUserRole == 'owner';

              return ListView.separated(
                itemCount: members.length,
                separatorBuilder: (context, index) => const Divider(),
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
                        ? () => _showMemberOptions(context, member, group.id)
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
