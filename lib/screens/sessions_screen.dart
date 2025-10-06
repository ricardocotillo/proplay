import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/models/group_model.dart';

class SessionsScreen extends StatelessWidget {
  final GroupModel group;
  const SessionsScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
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
      ),
      body: const Center(
        child: Text('Sessions will be listed here.'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/group/${group.id}/sessions/create');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
