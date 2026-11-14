import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/bloc/auth/auth_state.dart';
import 'package:proplay/utils/document.dart';
import 'package:proplay/widgets/responsive_layout.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _groupCodeController = TextEditingController();
  final _documentController = TextEditingController();
  final _docFieldKey = GlobalKey<FormFieldState<String>>();
  DocumentType _docType = DocumentType.dni;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _groupCodeController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  void _register() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        documentType: _docType,
        documentNumber: normalizeDocument(_documentController.text),
        groupCode: _groupCodeController.text.trim(),
      ),
    );
  }

  void _signInWithGoogle() {
    // The document is mandatory before the Google popup opens.
    if (!_docFieldKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthGoogleSignInRequested(
        groupCode: _groupCodeController.text.trim().isEmpty
            ? null
            : _groupCodeController.text.trim(),
        documentType: _docType,
        documentNumber: normalizeDocument(_documentController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regístrate')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is AuthAuthenticated) {
            // Pop back to let AuthWrapper handle navigation to MyHomePage
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (state is AuthSuccessWithInfo) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return ResponsiveConstrainedBox(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.person_add_outlined, size: 80),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      enabled: !isLoading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Apellido',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      enabled: !isLoading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu apellido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<DocumentType>(
                      segments: const [
                        ButtonSegment(
                          value: DocumentType.dni,
                          label: Text('DNI'),
                        ),
                        ButtonSegment(
                          value: DocumentType.ce,
                          label: Text('Carnet de extranjería'),
                        ),
                      ],
                      selected: {_docType},
                      onSelectionChanged: isLoading
                          ? null
                          : (s) => setState(() {
                              _docType = s.first;
                              if (_documentController.text.isNotEmpty) {
                                _docFieldKey.currentState?.validate();
                              }
                            }),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: _docFieldKey,
                      controller: _documentController,
                      decoration: const InputDecoration(
                        labelText: 'Número de documento',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      keyboardType: _docType == DocumentType.dni
                          ? TextInputType.number
                          : TextInputType.text,
                      enabled: !isLoading,
                      validator: (v) => validateDocument(_docType, v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isLoading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu correo electrónico';
                        }
                        if (!value.contains('@')) {
                          return 'Por favor, ingresa un correo electrónico válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      enabled: !isLoading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa una contraseña';
                        }
                        if (value.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      enabled: !isLoading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, confirma tu contraseña';
                        }
                        if (value != _passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _groupCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Código de Grupo (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.group),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Regístrate'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'O',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: Image.asset(
                        'assets/google.png',
                        height: 24,
                        width: 24,
                      ),
                      label: const Text('Registrate con Google'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: isLoading ? null : () => context.pop(),
                      child: const Text('¿Ya tienes una cuenta? Inicia sesión'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
