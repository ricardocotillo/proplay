import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/models/group_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/screens/group_info_screen.dart';

class GroupInfoScreenLoader extends StatefulWidget {
  final String groupId;

  const GroupInfoScreenLoader({super.key, required this.groupId});

  @override
  State<GroupInfoScreenLoader> createState() => _GroupInfoScreenLoaderState();
}

class _GroupInfoScreenLoaderState extends State<GroupInfoScreenLoader> {
  late final GroupService _groupService;
  Future<GroupModel?>? _groupFuture;

  @override
  void initState() {
    super.initState();
    _groupService = context.read<GroupService>();
    _groupFuture = _groupService.getGroup(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GroupModel?>(
      future: _groupFuture,
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
