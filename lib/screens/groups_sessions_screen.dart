import 'package:flutter/material.dart';
import 'package:proplay/screens/create_session_screen.dart';

class GroupsSessionsScreen extends StatelessWidget {
  final String groupId;
  const GroupsSessionsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateSessionScreen(groupId: groupId),
                ),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Upcoming sessions will be displayed here.'),
      ),
    );
  }
}
