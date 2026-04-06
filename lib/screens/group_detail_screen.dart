import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
            TextButton(
              child: Text(
                'Pichangas',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        GroupsSessionsScreen(groupId: group.id),
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
              child: Text(
                group.code,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
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

              final isDesktop = ResponsiveBreakpoints.of(
                context,
              ).largerThan(TABLET);

              if (isDesktop) {
                return _buildDesktopLayout(
                  context,
                  members,
                  currentUser,
                  isOwner,
                );
              }

              return _buildMobileLayout(context, members, currentUser, isOwner);
            }

            return const Center(child: Text('Error cargando miembros'));
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    List<GroupMemberModel> members,
    dynamic currentUser,
    bool isOwner,
  ) {
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
                ? CachedNetworkImageProvider(member.user.profileImageUrl!)
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

  Widget _buildDesktopLayout(
    BuildContext context,
    List<GroupMemberModel> members,
    dynamic currentUser,
    bool isOwner,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left pane: Group Info
        Expanded(flex: 1, child: _buildGroupInfoPanel(context)),
        const VerticalDivider(width: 1),
        // Right pane: Members List
        Expanded(
          flex: 2,
          child: _buildMembersPanel(context, members, currentUser, isOwner),
        ),
      ],
    );
  }

  Widget _buildGroupInfoPanel(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Avatar
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Group Name
          Text(
            'Nombre del Grupo',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            group.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Sport
          Text(
            'Deporte',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            group.sport.isNotEmpty
                ? group.sport[0].toUpperCase() + group.sport.substring(1)
                : 'Sin definir',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),

          // Code
          Text(
            'Código de Invitación',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  group.code,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy),
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
                tooltip: 'Copiar código',
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Actions
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupsSessionsScreen(groupId: group.id),
                ),
              );
            },
            icon: const Icon(Icons.sports),
            label: const Text('Ver Pichangas'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/group/${group.id}/edit'),
            icon: const Icon(Icons.edit),
            label: const Text('Editar Grupo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersPanel(
    BuildContext context,
    List<GroupMemberModel> members,
    dynamic currentUser,
    bool isOwner,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Miembros',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${members.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Members List
        Expanded(
          child: ListView.separated(
            itemCount: members.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = members[index];
              final isCurrentUser = member.userId == currentUser?.uid;
              final canChangeRole =
                  isOwner && !isCurrentUser && member.role != 'owner';

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: member.user.profileImageUrl != null
                      ? CachedNetworkImageProvider(member.user.profileImageUrl!)
                      : null,
                  child: member.user.profileImageUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(member.user.fullName),
                subtitle: Text(member.roleLabel),
                trailing: canChangeRole
                    ? IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () =>
                            _showMemberOptions(context, member, group.id),
                      )
                    : null,
                onLongPress: canChangeRole
                    ? () => _showMemberOptions(context, member, group.id)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
