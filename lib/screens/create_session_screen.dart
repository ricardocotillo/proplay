import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:proplay/bloc/session/session_bloc.dart';
import 'package:proplay/bloc/session/session_event.dart';
import 'package:proplay/bloc/session/session_state.dart';
import 'package:proplay/models/session_template_model.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/utils/auth_helper.dart';

class CreateSessionScreen extends StatefulWidget {
  final String groupId;
  const CreateSessionScreen({super.key, required this.groupId});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _maxPlayersController = TextEditingController();
  final _maxWaitingListController = TextEditingController();
  final _totalCostController = TextEditingController();
  final _rruleController = TextEditingController();

  DateTime? _joinDate;
  DateTime? _cutOffDate;
  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  DateTime? _eventEndDate;
  TimeOfDay? _eventEndTime;
  bool _isRecurring = false;

  @override
  void dispose() {
    _titleController.dispose();
    _maxPlayersController.dispose();
    _maxWaitingListController.dispose();
    _totalCostController.dispose();
    _rruleController.dispose();
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

      if (_joinDate == null ||
          _cutOffDate == null ||
          _eventDate == null ||
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
        joinDate: Timestamp.fromDate(_joinDate!),
        cutOffDate: Timestamp.fromDate(_cutOffDate!),
        eventDate: Timestamp.fromDate(eventDateTime),
        eventEndDate: Timestamp.fromDate(eventEndDateTime),
        maxPlayers: int.parse(_maxPlayersController.text),
        maxWaitingList: int.parse(_maxWaitingListController.text),
        totalCost: double.parse(_totalCostController.text),
        isRecurring: _isRecurring,
        rrule: _isRecurring ? _rruleController.text : null,
      );

      context.read<SessionBloc>().add(SessionTemplateCreateRequested(template));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SessionBloc(sessionService: SessionService()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Create Session')),
        body: BlocListener<SessionBloc, SessionState>(
          listener: (context, state) {
            if (state is SessionCreationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Session created successfully!')),
              );
              Navigator.of(context).pop();
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
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildDateTimePicker(
                    context: context,
                    label: 'Join Date',
                    date: _joinDate,
                    onDatePicked: (date) => setState(() => _joinDate = date),
                  ),
                  const SizedBox(height: 16),
                  _buildDateTimePicker(
                    context: context,
                    label: 'Cut-Off Date',
                    date: _cutOffDate,
                    onDatePicked: (date) => setState(() => _cutOffDate = date),
                  ),
                  const SizedBox(height: 16),
                  _buildDateTimePicker(
                    context: context,
                    label: 'Event Start',
                    date: _eventDate,
                    time: _eventTime,
                    onDatePicked: (date) => setState(() => _eventDate = date),
                    onTimePicked: (time) => setState(() => _eventTime = time),
                  ),
                  const SizedBox(height: 16),
                  _buildDateTimePicker(
                    context: context,
                    label: 'Event End',
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
                    decoration: const InputDecoration(labelText: 'Max Players'),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter max players' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _maxWaitingListController,
                    decoration: const InputDecoration(
                      labelText: 'Max Waiting List',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter max waiting list' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _totalCostController,
                    decoration: const InputDecoration(labelText: 'Total Cost'),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter total cost' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Is Recurring?'),
                      Switch(
                        value: _isRecurring,
                        onChanged: (value) =>
                            setState(() => _isRecurring = value),
                      ),
                    ],
                  ),
                  if (_isRecurring)
                    TextFormField(
                      controller: _rruleController,
                      decoration: const InputDecoration(
                        labelText: 'Recurrence Rule (rrule)',
                      ),
                      validator: (value) => _isRecurring && value!.isEmpty
                          ? 'Please enter a recurrence rule'
                          : null,
                    ),
                  const SizedBox(height: 32),
                  Center(
                    child: BlocBuilder<SessionBloc, SessionState>(
                      builder: (context, state) {
                        if (state is SessionCreationLoading) {
                          return const CircularProgressIndicator();
                        }
                        return ElevatedButton(
                          onPressed: _submitForm,
                          child: const Text('Create Session'),
                        );
                      },
                    ),
                  ),
                ],
              ),
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
                    date != null ? dateFormat.format(date) : 'Select Date',
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
                      time != null ? time.format(context) : 'Select Time',
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
