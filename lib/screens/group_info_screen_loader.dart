import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/models/group_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/screens/group_info_screen.dart';

class GroupInfoScreenLoader extends StatelessWidget {
  final String groupId;

  const GroupInfoScreenLoader({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final groupService = context.read<GroupService>();

    return StreamBuilder<GroupModel?>(
      stream: groupService.streamGroup(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('Group not found or failed to load.')),
          );
        } else {
          return GroupInfoScreen(group: snapshot.data!);
        }
      },
    );
  }
}
