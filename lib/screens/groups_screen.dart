import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/bloc/group/group_event.dart';
import 'package:proplay/bloc/group/group_state.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// "Grupos" tab: the user's groups, with create and join-by-code.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  void _loadGroups() {
    final user = context.currentUser;
    if (user != null) {
      context.read<GroupBloc>().add(GroupLoadUserGroups(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    return Scaffold(
      appBar: isDesktop ? null : AppBar(title: const Text('Grupos')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1400 : double.infinity,
          ),
          child: BlocConsumer<GroupBloc, GroupState>(
            listener: (context, state) {
              if (state is GroupJoinSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.success,
                  ),
                );
                _loadGroups();
              } else if (state is GroupDeleteSuccess) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(state.message)));
                _loadGroups();
              }
            },
            builder: (context, state) {
              if (state is GroupLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is GroupLoaded) {
                return ListView(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  children: [
                    state.groups.isEmpty
                        ? _buildEmptyState(context)
                        : _buildGroupsList(state.groups),
                  ],
                );
              }
              if (state is GroupError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No pudimos cargar tus grupos',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: _loadGroups,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }
              return ListView(children: [_buildEmptyState(context)]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.titleLarge,
            children: [
              const TextSpan(text: 'No tienes un grupo aun? '),
              WidgetSpan(
                child: GestureDetector(
                  onTap: () {
                    context.push('/create-group').then((result) {
                      if (result != null) {
                        _loadGroups();
                      }
                    });
                  },
                  child: Text(
                    'crea',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const TextSpan(text: ' o '),
              WidgetSpan(
                child: GestureDetector(
                  onTap: () => _showJoinGroupDialog(),
                  child: Text(
                    'unete a uno',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupsList(List groups) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(DESKTOP);
    final isTablet = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    // Determine grid columns based on screen size
    int crossAxisCount = 1;
    if (isDesktop) {
      crossAxisCount = 3;
    } else if (isTablet) {
      crossAxisCount = 2;
    }

    // Determine padding based on screen size
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            16,
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/create-group').then((result) {
                      if (result != null) {
                        _loadGroups();
                      }
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Grupo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showJoinGroupDialog(),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Unirse a Grupo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        isTablet
            ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _buildGroupCard(group);
                },
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _buildGroupCard(group);
                },
              ),
      ],
    );
  }

  Widget _buildGroupCard(dynamic group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        dense: true,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          group.sport.isNotEmpty
              ? group.sport[0].toUpperCase() + group.sport.substring(1)
              : '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            group.code,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        onTap: () {
          context.push('/group/${group.id}');
        },
      ),
    );
  }

  void _showJoinGroupDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unirse a Grupo'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Código del Grupo',
            border: OutlineInputBorder(),
            hintText: 'Ingresa el código de 6 caracteres',
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim().toUpperCase();
              if (code.length == 6) {
                final user = this.context.currentUser;
                if (user != null) {
                  this.context.read<GroupBloc>().add(
                    GroupJoinRequested(code: code, userId: user.uid),
                  );
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }
}
