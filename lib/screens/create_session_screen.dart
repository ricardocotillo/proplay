import 'package:flutter/material.dart';

class CreateSessionScreen extends StatelessWidget {
  const CreateSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Session'),
      ),
      body: const Center(
        child: Text('Session creation form will be here.'),
      ),
    );
  }
}
