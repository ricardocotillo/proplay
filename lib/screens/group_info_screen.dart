import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/models/group_model.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/bloc/group/group_event.dart';
import 'package:proplay/bloc/group/group_state.dart';

class GroupInfoScreen extends StatelessWidget {
  final GroupModel group;

  const GroupInfoScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return BlocListener<GroupBloc, GroupState>(
      listener: (context, state) {
        if (state is GroupDeleteSuccess) {
          context.go('/');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          });
        } else if (state is GroupError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
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
          title: const Text('Información del grupo'),
        ),
        body: Column(
          children: [
            const SizedBox(height: 40),
            // Profile Picture
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundImage: group.profileImageUrl != null
                    ? CachedNetworkImageProvider(group.profileImageUrl!)
                    : null,
                child: group.profileImageUrl == null
                    ? Text(
                        group.name.isNotEmpty
                            ? group.name[0].toUpperCase()
                            : '',
                        style: const TextStyle(fontSize: 48),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // Group Name
            Text(
              group.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            // Options
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar'),
              onTap: () => context.push('/group/${group.id}/edit'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Sesiones'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Media'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Eliminar grupo',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Eliminar grupo'),
                    content: Text(
                      '¿Estás seguro de que quieres eliminar el grupo "${group.name}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          context.read<GroupBloc>().add(
                            GroupDeleteRequested(group.id),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
