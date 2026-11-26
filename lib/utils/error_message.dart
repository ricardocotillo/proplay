import 'package:firebase_core/firebase_core.dart';

/// Text to show the user for a caught error: Firebase codes in Spanish,
/// our own `Exception('...')` messages without the `Exception: ` prefix.
String userMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'No tienes permiso para hacer esto.',
      'unavailable' => 'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
      'not-found' => 'No encontramos lo que buscas.',
      _ => 'Algo salió mal. Inténtalo de nuevo.',
    };
  }
  const prefix = 'Exception: ';
  final text = error.toString();
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}
