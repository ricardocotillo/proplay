/// Peruvian identity documents accepted at registration.
enum DocumentType {
  dni('DNI'),
  ce('CE');

  const DocumentType(this.label);
  final String label;
}

String normalizeDocument(String s) => s.trim().toUpperCase();

/// Returns a Spanish error message, or null when valid. Format only, no checksum.
String? validateDocument(DocumentType type, String? value) {
  final v = normalizeDocument(value ?? '');
  if (v.isEmpty) return 'Ingresa tu número de documento';
  switch (type) {
    case DocumentType.dni:
      return RegExp(r'^\d{8}$').hasMatch(v)
          ? null
          : 'El DNI debe tener 8 dígitos';
    case DocumentType.ce:
      return RegExp(r'^[A-Z0-9]{9,12}$').hasMatch(v)
          ? null
          : 'El carnet de extranjería debe tener entre 9 y 12 caracteres';
  }
}

/// Firestore doc id of the uniqueness lock in `documents/`.
String documentKey(DocumentType type, String number) =>
    '${type.name}_${normalizeDocument(number)}';
