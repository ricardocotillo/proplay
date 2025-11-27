import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/bloc/group/group_event.dart';
import 'package:proplay/bloc/group/group_state.dart';
import 'package:proplay/utils/auth_helper.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();

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

  final List<String> _selectedSports = [];

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  void _createGroup() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = context.currentUser;
    if (user == null) return;

    context.read<GroupBloc>().add(
          GroupCreateRequested(
            name: _groupNameController.text.trim(),
            sports: _selectedSports,
            createdBy: user.uid,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Grupo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: BlocConsumer<GroupBloc, GroupState>(
        listener: (context, state) {
          if (state is GroupCreateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Grupo creado! Código: ${state.group.code}'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop(state.group);
          } else if (state is GroupError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is GroupLoading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Group Name
                  TextFormField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Grupo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group),
                    ),
                    enabled: !isLoading,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa el nombre del grupo';
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
                      final sportDisplay = sport['display']!;
                      final sportValue = sport['value']!;
                      final isSelected = _selectedSports.contains(sportValue);
                      return FilterChip(
                        label: Text(sportDisplay),
                        selected: isSelected,
                        onSelected: isLoading
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedSports.add(sportValue);
                                  } else {
                                    _selectedSports.remove(sportValue);
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

                  // Info Text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Información',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Se generará automáticamente un código único para tu grupo. Podrás compartir este código con otros para que se unan.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Create Button
                  ElevatedButton(
                    onPressed: isLoading || _selectedSports.isEmpty ? null : _createGroup,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crear Grupo'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
