import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:map_location_picker/map_location_picker.dart';

import 'package:proplay/bloc/create_session/create_session_bloc.dart';
import 'package:proplay/models/group_model.dart';
import 'package:proplay/models/session_template_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/constants.dart';
import 'package:proplay/widgets/step_indicator.dart';

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
  // Step management
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Location data
  double? _locationLat;
  double? _locationLng;
  String? _locationAddress;

  // Step 2: Date/time data
  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  DateTime? _eventEndDate;
  TimeOfDay? _eventEndTime;

  // Step 3: Form data
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _maxPlayersController = TextEditingController();
  final _totalCostController = TextEditingController();
  String? _desiredGender;
  RangeValues _ageRange = const RangeValues(18, 80);
  bool _isPrivate = false;

  // Group data
  GroupModel? _group;
  bool _isLoadingGroup = true;

  static const List<String> _stepLabels = ['Ubicación', 'Fecha', 'Detalles'];

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
    _pageController.dispose();
    _titleController.dispose();
    _maxPlayersController.dispose();
    _totalCostController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);
  }

  bool get _isStep2Valid {
    if (_eventDate == null ||
        _eventTime == null ||
        _eventEndDate == null ||
        _eventEndTime == null) {
      return false;
    }
    final start = DateTime(
      _eventDate!.year,
      _eventDate!.month,
      _eventDate!.day,
      _eventTime!.hour,
      _eventTime!.minute,
    );
    final end = DateTime(
      _eventEndDate!.year,
      _eventEndDate!.month,
      _eventEndDate!.day,
      _eventEndTime!.hour,
      _eventEndTime!.minute,
    );
    return end.isAfter(start);
  }

  void _validateAndGoToStep3() {
    if (!_isStep2Valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, completa las fechas y horas correctamente.',
          ),
        ),
      );
      return;
    }
    _goToNextStep();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = context.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para crear una sesión.'),
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
      minAge: _ageRange.start.round(),
      maxAge: _ageRange.end.round(),
      desiredGender: _desiredGender!,
      locationLat: _locationLat,
      locationLng: _locationLng,
      locationAddress: _locationAddress,
    );

    context.read<CreateSessionBloc>().add(CreateSessionTemplate(template));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear sesión'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
              child: Column(
                children: [
                  StepIndicator(
                    currentStep: _currentStep,
                    totalSteps: 3,
                    stepLabels: _stepLabels,
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildLocationStep(),
                        _buildDateTimeStep(),
                        _buildDetailsStep(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLocationStep() {
    return MapLocationPicker(
      config: MapLocationPickerConfig(
        apiKey: AppConstants.googleMapsApiKey,
        initialPosition: _locationLat != null && _locationLng != null
            ? LatLng(_locationLat!, _locationLng!)
            : const LatLng(-12.0464, -77.0428), // Lima default
        onNext: (result) {
          if (result != null && result.geometry != null) {
            setState(() {
              _locationLat = result.geometry!.location.lat;
              _locationLng = result.geometry!.location.lng;
              _locationAddress = result.formattedAddress;
            });
            _goToNextStep();
          }
        },
      ),
      searchConfig: SearchConfig(
        apiKey: AppConstants.googleMapsApiKey,
        searchHintText: 'Buscar ubicación...',
      ),
    );
  }

  Widget _buildDateTimeStep() {
    final dateFormat = DateFormat.yMMMd('es');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location summary
          _buildSummaryCard(
            icon: Icons.location_on,
            title: 'Ubicación',
            subtitle: _locationAddress ?? 'No seleccionada',
            onTap: () => _goToStep(0),
          ),
          const SizedBox(height: 24),

          // Start date/time
          Text(
            'Fecha de inicio',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDatePickerField(
                  date: _eventDate,
                  dateFormat: dateFormat,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eventDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      setState(() => _eventDate = picked);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTimePickerField(
                  time: _eventTime,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _eventTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setState(() => _eventTime = picked);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // End date/time
          Text(
            'Fecha de finalización',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDatePickerField(
                  date: _eventEndDate,
                  dateFormat: dateFormat,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _eventEndDate ?? _eventDate ?? DateTime.now(),
                      firstDate: _eventDate ?? DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      setState(() => _eventEndDate = picked);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTimePickerField(
                  time: _eventEndTime,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          _eventEndTime ?? _eventTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setState(() => _eventEndTime = picked);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Navigation buttons
          Row(
            children: [
              TextButton.icon(
                onPressed: _goToPreviousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Atrás'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _validateAndGoToStep3,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Siguiente'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');

    String formatDateTime(DateTime? date, TimeOfDay? time) {
      if (date == null || time == null) return 'No seleccionado';
      final dt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      return dateFormat.format(dt);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summaries
            _buildSummaryCard(
              icon: Icons.location_on,
              title: 'Ubicación',
              subtitle: _locationAddress ?? 'No seleccionada',
              onTap: () => _goToStep(0),
            ),
            const SizedBox(height: 8),
            _buildSummaryCard(
              icon: Icons.calendar_today,
              title: 'Fecha y hora',
              subtitle:
                  '${formatDateTime(_eventDate, _eventTime)} - ${formatDateTime(_eventEndDate, _eventEndTime)}',
              onTap: () => _goToStep(1),
            ),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Por favor, ingresa un título' : null,
            ),
            const SizedBox(height: 16),

            // Max players
            TextFormField(
              controller: _maxPlayersController,
              decoration: const InputDecoration(
                labelText: 'Máximo de jugadores',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty
                  ? 'Por favor, ingresa el número de jugadores'
                  : null,
            ),
            const SizedBox(height: 16),

            // Total cost
            TextFormField(
              controller: _totalCostController,
              decoration: const InputDecoration(
                labelText: 'Costo total',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value!.isEmpty ? 'Por favor, ingresa el costo total' : null,
            ),
            const SizedBox(height: 16),

            // Age range
            _buildAgeRangeField(),
            const SizedBox(height: 16),

            // Gender dropdown
            DropdownButtonFormField<String>(
              initialValue: _desiredGender,
              decoration: const InputDecoration(
                labelText: 'Género deseado',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'any', child: Text('Cualquiera')),
                DropdownMenuItem(value: 'male', child: Text('Masculino')),
                DropdownMenuItem(value: 'female', child: Text('Femenino')),
              ],
              onChanged: (value) => setState(() => _desiredGender = value),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Por favor, selecciona una opción'
                  : null,
            ),
            const SizedBox(height: 16),

            // Private checkbox
            CheckboxListTile(
              title: const Text('Sesión privada'),
              subtitle: const Text(
                'Solo los miembros del grupo podrán ver esta sesión',
              ),
              value: _isPrivate,
              onChanged: (value) => setState(() => _isPrivate = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            // Navigation buttons
            Row(
              children: [
                TextButton.icon(
                  onPressed: _goToPreviousStep,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Atrás'),
                ),
                const Spacer(),
                BlocBuilder<CreateSessionBloc, CreateSessionState>(
                  builder: (context, state) {
                    if (state is CreateSessionLoading) {
                      return const CircularProgressIndicator();
                    }
                    return FilledButton.icon(
                      onPressed: _submitForm,
                      icon: const Icon(Icons.check),
                      label: const Text('Crear Sesión'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.edit, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDatePickerField({
    required DateTime? date,
    required DateFormat dateFormat,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? dateFormat.format(date) : 'Seleccionar fecha',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerField({
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                time != null ? time.format(context) : 'Seleccionar hora',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeRangeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rango de edad: ${_ageRange.start.round()} - ${_ageRange.end.round()}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        RangeSlider(
          values: _ageRange,
          min: 18,
          max: 80,
          divisions: 62,
          labels: RangeLabels(
            '${_ageRange.start.round()}',
            '${_ageRange.end.round()}',
          ),
          onChanged: (newRange) => setState(() => _ageRange = newRange),
        ),
      ],
    );
  }
}
