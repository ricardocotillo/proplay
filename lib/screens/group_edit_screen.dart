import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;

  // Available sports
  final List<Map<String, String>> _availableSports = [
    {'display': 'Fútbol', 'value': 'fútbol'},
    {'display': 'Baloncesto', 'value': 'baloncesto'},
    {'display': 'Voleibol', 'value': 'voleibol'},
    {'display': 'Tenis', 'value': 'tenis'},
    {'display': 'Natación', 'value': 'natación'},
    {'display': 'Running', 'value': 'running'},
    {'display': 'Ciclismo', 'value': 'ciclismo'},
    {'display': 'Gimnasio', 'value': 'gimnasio'},
    {'display': 'Pádel', 'value': 'pádel'},
    {'display': 'Béisbol', 'value': 'béisbol'},
  ];

  String? _selectedSport;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _selectedSport = widget.group.sport;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _saveGroup(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      if (_selectedSport == null || _selectedSport!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor selecciona un deporte'),
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
          sport: _selectedSport!,
          profileImage: _selectedImage,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          GroupEditBloc(groupService: GroupService(userService: UserService())),
      child: BlocListener<GroupEditBloc, GroupEditState>(
        listener: (context, state) {
          if (state is GroupEditSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
            if (state.message.contains('deleted')) {
              context.go('/');
            } else {
              context.pop();
            }
          } else if (state is GroupEditFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error)));
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
                      // Profile Image Section
                      Center(
                        child: GestureDetector(
                          onTap: isLoading ? null : _pickImage,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundImage: _selectedImage != null
                                    ? FileImage(_selectedImage!)
                                    : (widget.group.profileImageUrl != null
                                              ? CachedNetworkImageProvider(
                                                  widget.group.profileImageUrl!,
                                                )
                                              : null)
                                          as ImageProvider?,
                                child:
                                    (_selectedImage == null &&
                                        widget.group.profileImageUrl == null)
                                    ? Text(
                                        widget.group.name.isNotEmpty
                                            ? widget.group.name[0].toUpperCase()
                                            : 'G',
                                        style: const TextStyle(fontSize: 40),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Group Name',
                        ),
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
                        'Selecciona Deporte',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableSports.map((sport) {
                          final sportDisplay = sport['display']!;
                          final sportValue = sport['value']!;
                          final isSelected = _selectedSport == sportValue;
                          return ChoiceChip(
                            label: Text(sportDisplay),
                            selected: isSelected,
                            onSelected: isLoading
                                ? null
                                : (selected) {
                                    setState(() {
                                      _selectedSport = selected ? sportValue : null;
                                    });
                                  },
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          );
                        }).toList(),
                      ),
                      if (_selectedSport == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Por favor selecciona un deporte',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        ElevatedButton(
                          onPressed: isLoading || _selectedSport == null
                              ? null
                              : () => _saveGroup(context),
                          child: const Text('Save Changes'),
                        ),
                      ],
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
