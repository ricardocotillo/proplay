import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/models/group_model.dart';
import 'package:proplay/models/group_member_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/user_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final GroupService _groupService = GroupService(userService: UserService());
  final UserService _userService = UserService();
  List<GroupMemberModel> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final membersData = await _groupService.getGroupMembers(widget.group.id);
      List<GroupMemberModel> members = [];
      for (var memberData in membersData) {
        final user = await _userService.getUser(memberData['userId']);
        if (user != null) {
          members.add(GroupMemberModel.fromMap(memberData, user));
        }
      }
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

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
        title: Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/group/${widget.group.id}/edit'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: member.user.profileImageUrl != null
                        ? NetworkImage(member.user.profileImageUrl!)
                        : null,
                    child: member.user.profileImageUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(member.user.fullName),
                  subtitle: Text(member.roleLabel),
                );
              },
            ),
    );
  }
}
