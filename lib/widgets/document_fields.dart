import 'package:material_ui/material_ui.dart';
import 'package:proplay/utils/document.dart';

/// DNI / carnet de extranjería selector + number field, shared by
/// registration and the "add your document" dialog.
class DocumentFields extends StatelessWidget {
  final DocumentType type;
  final ValueChanged<DocumentType> onTypeChanged;
  final TextEditingController controller;
  final GlobalKey<FormFieldState<String>>? fieldKey;
  final bool enabled;

  const DocumentFields({
    super.key,
    required this.type,
    required this.onTypeChanged,
    required this.controller,
    this.fieldKey,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<DocumentType>(
          segments: const [
            ButtonSegment(value: DocumentType.dni, label: Text('DNI')),
            ButtonSegment(
              value: DocumentType.ce,
              label: Text('Carnet de extranjería'),
            ),
          ],
          selected: {type},
          onSelectionChanged: enabled ? (s) => onTypeChanged(s.first) : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: fieldKey,
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Número de documento',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.badge),
          ),
          keyboardType: type == DocumentType.dni
              ? TextInputType.number
              : TextInputType.text,
          enabled: enabled,
          validator: (v) => validateDocument(type, v),
        ),
      ],
    );
  }
}
