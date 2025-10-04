
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/bloc/group_edit/group_edit_bloc.dart';
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

  // Available sports
  final List<String> _availableSports = [
    'Fútbol',
    'Baloncesto',
    'Tenis',
    'Voleibol',
    'Béisbol',
    'Rugby',
    'Natación',
    'Ciclismo',
    'Atletismo',
    'Gimnasia',
  ];

  final List<String> _selectedSports = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _selectedSports.addAll(widget.group.sports);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveGroup(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      if (_selectedSports.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one sport'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final newName = _nameController.text;
      context.read<GroupEditBloc>().add(
            GroupEditSubmitted(
              groupId: widget.group.id,
              name: newName,
              sports: _selectedSports,
            ),
          );
    }
  }

  void _deleteGroup(BuildContext context) async {
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
      // ignore: use_build_context_synchronously
      context.read<GroupEditBloc>().add(GroupDeleted(widget.group.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GroupEditBloc(
        groupService: GroupService(userService: UserService()),
      ),
      child: BlocListener<GroupEditBloc, GroupEditState>(
        listener: (context, state) {
          if (state is GroupEditSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            if (state.message.contains('deleted')) {
              context.go('/');
            } else {
              context.pop();
            }
          } else if (state is GroupEditFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error)),
            );
          }
        },
        child: BlocBuilder<GroupEditBloc, GroupEditState>(
          builder: (context, state) {
            final isLoading = state is GroupEditInProgress;
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
                title: const Text('Edit Group'),
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      const SizedBox(height: 24),

                      // Sports Selection
                      Text(
                        'Selecciona Deportes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableSports.map((sport) {
                          final isSelected = _selectedSports.contains(sport);
                          return FilterChip(
                            label: Text(sport),
                            selected: isSelected,
                            onSelected: isLoading
                                ? null
                                : (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedSports.add(sport);
                                      } else {
                                        _selectedSports.remove(sport);
                                      }
                                    });
                                  },
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          );
                        }).toList(),
                      ),
                      if (_selectedSports.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Por favor selecciona al menos un deporte',
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      const SizedBox(height: 32),
                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        ElevatedButton(
                          onPressed: isLoading || _selectedSports.isEmpty
                              ? null
                              : () => _saveGroup(context),
                          child: const Text('Save Changes'),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => _deleteGroup(context),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Eliminar Grupo'),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
