import 'package:flutter/material.dart';
import 'package:proplay/models/group_model.dart';

class GroupEditScreen extends StatelessWidget {
  final GroupModel group;

  const GroupEditScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Group')),
      body: const Center(child: Text('Edit Group Form')),
    );
  }
}
