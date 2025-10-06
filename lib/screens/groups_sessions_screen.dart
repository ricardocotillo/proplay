
import 'package:flutter/material.dart';

class GroupsSessionsScreen extends StatelessWidget {
  const GroupsSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
      ),
      body: const Center(
        child: Text('Upcoming sessions will be displayed here.'),
      ),
    );
  }
}
