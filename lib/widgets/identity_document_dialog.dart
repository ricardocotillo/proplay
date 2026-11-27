import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/bloc/auth/auth_state.dart';
import 'package:proplay/bloc/identity_document/identity_document_cubit.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/document.dart';
import 'package:proplay/widgets/document_fields.dart';

/// Asks a legacy player (no DNI/CE on the account) for their document before
/// joining an event or a waitlist. With [correcting] it edits the existing
/// document instead (prefilled, once every 30 days). Returns true once saved.
Future<bool> askIdentityDocument(
  BuildContext context, {
  bool correcting = false,
}) async {
  final uid = context.currentUser!.uid;
  final userService = context.read<UserService>();
  final authBloc = context.read<AuthBloc>();
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => IdentityDocumentCubit(userService, uid),
      child: _IdentityDocumentDialog(correcting: correcting),
    ),
  );
  if (saved != true) return false;
  // Wait for the fresh profile: a quick second tap must not see the stale
  // account (no document) and reopen this dialog.
  authBloc.add(const AuthRefreshUserRequested());
  await authBloc.stream
      .firstWhere((s) => s is AuthAuthenticated && s.userModel.hasDocument)
      .timeout(const Duration(seconds: 5), onTimeout: () => authBloc.state);
  return true;
}

class _IdentityDocumentDialog extends StatefulWidget {
  const _IdentityDocumentDialog({required this.correcting});

  final bool correcting;

  @override
  State<_IdentityDocumentDialog> createState() =>
      _IdentityDocumentDialogState();
}

class _IdentityDocumentDialogState extends State<_IdentityDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  DocumentType _type = DocumentType.dni;

  @override
  void initState() {
    super.initState();
    final user = context.currentUser;
    if (widget.correcting && user != null && user.hasDocument) {
      _type = DocumentType.values.byName(user.documentType);
      _controller.text = user.documentNumber;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<IdentityDocumentCubit>();
    widget.correcting
        ? cubit.change(_type, _controller.text)
        : cubit.save(_type, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IdentityDocumentCubit, IdentityDocumentState>(
      listener: (context, state) {
        if (state.status == IdentityDocumentStatus.saved) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final saving = state.status == IdentityDocumentStatus.saving;
        return AlertDialog(
          title: Text(
            widget.correcting
                ? 'Corregir documento'
                : 'Tu documento de identidad',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.correcting
                        ? 'Solo puedes cambiarlo una vez cada '
                              '$kDocumentCooldownDays días. Tus tickets '
                              'actuales conservan el documento anterior.'
                        : 'Por seguridad, los organizadores necesitan saber '
                              'quién asiste. Lo pedimos una sola vez y el '
                              'staff lo verá al escanear tu ticket.',
                  ),
                  const SizedBox(height: 16),
                  DocumentFields(
                    type: _type,
                    fieldKey: _fieldKey,
                    controller: _controller,
                    enabled: !saving,
                    onTypeChanged: (t) {
                      setState(() => _type = t);
                      // After the rebuild: the validator reads the new type.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_controller.text.isNotEmpty) {
                          _fieldKey.currentState?.validate();
                        }
                      });
                    },
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.error!,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: saving ? null : _save,
              child: Text(
                widget.correcting ? 'Guardar' : 'Guardar y continuar',
              ),
            ),
          ],
        );
      },
    );
  }
}
