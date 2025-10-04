import 'package:flutter/material.dart';
import 'package:proplay/models/group_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/user_service.dart';

class GroupEditScreen extends StatefulWidget {
  final GroupModel group;

  const GroupEditScreen({super.key, required this.group});

  @override
  State<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends State<GroupEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _sportsController;
  final GroupService _groupService = GroupService(userService: UserService());

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _sportsController = TextEditingController(text: widget.group.sports.join(', '));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sportsController.dispose();
    super.dispose();
  }

  void _saveGroup() async {
    if (_formKey.currentState!.validate()) {
      final newName = _nameController.text;
      final newSports = _sportsController.text.split(',').map((s) => s.trim()).toList();

      try {
        await _groupService.updateGroup(widget.group.id, {
          'name': newName,
          'sports': newSports,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group updated successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update group: $e')),
          );
        }
      }
    }
  }

  void _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Grupo'),
        content: const Text('Are you sure you want to delete this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _groupService.deleteGroup(widget.group.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group deleted successfully')),
          );
          // Pop until we are back at the home screen
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete group: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Group'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sportsController,
                decoration: const InputDecoration(labelText: 'Sports (comma separated)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter at least one sport';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveGroup,
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _deleteGroup,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar Grupo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}