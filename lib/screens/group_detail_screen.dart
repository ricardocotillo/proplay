
import 'package:flutter/material.dart';
import 'package:proplay/models/group_model.dart';
import 'package:proplay/models/user_model.dart';
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
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final membersData = await _groupService.getGroupMembers(widget.group.id);
      List<Map<String, dynamic>> members = [];
      for (var memberData in membersData) {
        UserModel? user = await _userService.getUser(memberData['userId']);
        if (user != null) {
          members.add({
            'user': user,
            'role': memberData['role'],
          });
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
        title: Text(widget.group.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                final UserModel user = member['user'];
                final String role = member['role'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.profileImageUrl != null
                        ? NetworkImage(user.profileImageUrl!)
                        : null,
                    child: user.profileImageUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user.fullName),
                  subtitle: Text(role),
                );
              },
            ),
    );
  }
}
