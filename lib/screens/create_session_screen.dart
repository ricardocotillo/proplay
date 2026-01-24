import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proplay/bloc/create_session/create_session_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:proplay/models/session_template_model.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/models/group_model.dart';

class CreateSessionScreen extends StatelessWidget {
  final String groupId;
  const CreateSessionScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CreateSessionBloc(sessionService: SessionService()),
      child: _CreateSessionContent(groupId: groupId),
    );
  }
}

class _CreateSessionContent extends StatefulWidget {
  final String groupId;
  const _CreateSessionContent({required this.groupId});

  @override
  State<_CreateSessionContent> createState() => _CreateSessionContentState();
}

class _CreateSessionContentState extends State<_CreateSessionContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _maxPlayersController = TextEditingController();
  final _totalCostController = TextEditingController();
  String? _desiredGender;
  RangeValues _ageRange = const RangeValues(18, 80);

  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  DateTime? _eventEndDate;
  TimeOfDay? _eventEndTime;
  bool _isPrivate = false;
  GroupModel? _group;
  bool _isLoadingGroup = true;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      final groupService = GroupService(userService: UserService());
      final group = await groupService.getGroup(widget.groupId);
      if (mounted) {
        setState(() {
          _group = group;
          _isLoadingGroup = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGroup = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar el grupo: $e')));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _maxPlayersController.dispose();
    _totalCostController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final currentUser = context.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to create a session.'),
          ),
        );
        return;
      }

      if (_eventDate == null ||
          _eventTime == null ||
          _eventEndDate == null ||
          _eventEndTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all date and time fields.'),
          ),
        );
        return;
      }

      if (_group == null || _group!.sport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: El grupo no tiene deporte asignado.'),
          ),
        );
        return;
      }

      if (_desiredGender == null || _desiredGender!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecciona el género deseado.'),
          ),
        );
        return;
      }

      final minAge = _ageRange.start.round();
      final maxAge = _ageRange.end.round();

      final eventDateTime = DateTime(
        _eventDate!.year,
        _eventDate!.month,
        _eventDate!.day,
        _eventTime!.hour,
        _eventTime!.minute,
      );
      final eventEndDateTime = DateTime(
        _eventEndDate!.year,
        _eventEndDate!.month,
        _eventEndDate!.day,
        _eventEndTime!.hour,
        _eventEndTime!.minute,
      );

      final template = SessionTemplateModel(
        groupId: widget.groupId,
        creatorId: currentUser.uid,
        title: _titleController.text,
        eventDate: Timestamp.fromDate(eventDateTime),
        eventEndDate: Timestamp.fromDate(eventEndDateTime),
        maxPlayers: int.parse(_maxPlayersController.text),
        totalCost: double.parse(_totalCostController.text),
        isPrivate: _isPrivate,
        sport: _group!.sport,
        minAge: minAge,
        maxAge: maxAge,
        desiredGender: _desiredGender!,
      );

      context.read<CreateSessionBloc>().add(CreateSessionTemplate(template));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear sesión')),
      body: _isLoadingGroup
          ? const Center(child: CircularProgressIndicator())
          : BlocListener<CreateSessionBloc, CreateSessionState>(
              listener: (context, state) {
                if (state is SessionCreationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sesión creada exitosamente!'),
                    ),
                  );
                  Navigator.of(context).pop(true);
                }
                if (state is SessionCreationFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${state.message}')),
                  );
                }
              },
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Título'),
                        validator: (value) => value!.isEmpty
                            ? 'Por favor, ingresa un título'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildDateTimePicker(
                        context: context,
                        label: 'Fecha de inicio',
                        date: _eventDate,
                        time: _eventTime,
                        onDatePicked: (date) =>
                            setState(() => _eventDate = date),
                        onTimePicked: (time) =>
                            setState(() => _eventTime = time),
                      ),
                      const SizedBox(height: 16),
                      _buildDateTimePicker(
                        context: context,
                        label: 'Fecha de finalización',
                        date: _eventEndDate,
                        time: _eventEndTime,
                        onDatePicked: (date) =>
                            setState(() => _eventEndDate = date),
                        onTimePicked: (time) =>
                            setState(() => _eventEndTime = time),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _maxPlayersController,
                        decoration: const InputDecoration(
                          labelText: 'Máximo de jugadores',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty
                            ? 'Por favor, ingresa el número de jugadores'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _totalCostController,
                        decoration: const InputDecoration(
                          labelText: 'Costo total',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty
                            ? 'Por favor, ingresa el costo total'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      FormField<RangeValues>(
                        initialValue: _ageRange,
                        validator: (value) {
                          if (value == null) {
                            return 'Por favor, selecciona un rango de edad';
                          }
                          if (value.start < 18 || value.end > 80) {
                            return 'El rango debe ser entre 18 y 80';
                          }
                          if (value.start > value.end) {
                            return 'Por favor, selecciona un rango válido';
                          }
                          return null;
                        },
                        builder: (field) {
                          final range = field.value ?? _ageRange;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rango de edad: ${range.start.round()} - ${range.end.round()}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              RangeSlider(
                                values: range,
                                min: 18,
                                max: 80,
                                divisions: 62,
                                labels: RangeLabels(
                                  '${range.start.round()}',
                                  '${range.end.round()}',
                                ),
                                onChanged: (newRange) {
                                  setState(() {
                                    _ageRange = newRange;
                                  });
                                  field.didChange(newRange);
                                },
                              ),
                              if (field.hasError)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    field.errorText ?? '',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _desiredGender,
                        decoration: const InputDecoration(
                          labelText: 'Género deseado',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'any',
                            child: Text('Cualquiera'),
                          ),
                          DropdownMenuItem(
                            value: 'male',
                            child: Text('Masculino'),
                          ),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Femenino'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _desiredGender = value;
                          });
                        },
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Por favor, selecciona una opción'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Sesión privada'),
                        subtitle: const Text(
                          'Solo los miembros del grupo podrán ver esta sesión',
                        ),
                        value: _isPrivate,
                        onChanged: (value) {
                          setState(() {
                            _isPrivate = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child:
                            BlocBuilder<CreateSessionBloc, CreateSessionState>(
                              builder: (context, state) {
                                if (state is CreateSessionLoading) {
                                  return const CircularProgressIndicator();
                                }
                                return ElevatedButton(
                                  onPressed: _submitForm,
                                  child: const Text('Crear Sesión'),
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDateTimePicker({
    required BuildContext context,
    required String label,
    DateTime? date,
    TimeOfDay? time,
    required ValueChanged<DateTime> onDatePicked,
    ValueChanged<TimeOfDay>? onTimePicked,
  }) {
    final dateFormat = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: date ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    onDatePicked(pickedDate);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 15,
                    ),
                  ),
                  child: Text(
                    date != null
                        ? dateFormat.format(date)
                        : 'Seleccionar fecha',
                  ),
                ),
              ),
            ),
            if (onTimePicked != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: time ?? TimeOfDay.now(),
                    );
                    if (pickedTime != null) {
                      onTimePicked(pickedTime);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 15,
                      ),
                    ),
                    child: Text(
                      time != null ? time.format(context) : 'Seleccionar hora',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
