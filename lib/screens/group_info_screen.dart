import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/models/group_model.dart';

class GroupInfoScreen extends StatelessWidget {
  final GroupModel group;

  const GroupInfoScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              child: Text(
                group.name.isNotEmpty ? group.name[0].toUpperCase() : '',
                style: const TextStyle(fontSize: 48),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Group Name
          Text(
            group.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 32),
          // Options
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editar'),
            onTap: () => context.push('/group/${group.id}/edit'),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Media'),
            onTap: () {
              // TODO: Implement media screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Eliminar grupo', style: TextStyle(color: Colors.red)),
            onTap: () {
              // TODO: Implement delete group functionality
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
                        // TODO: Implement delete logic
                        Navigator.pop(dialogContext);
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
    );
  }
}
