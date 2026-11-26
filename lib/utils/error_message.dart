import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Text to show the user for a caught error: Firebase codes in Spanish,
/// our own `Exception('...')` messages without the `Exception: ` prefix.
String userMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'No tienes permiso para hacer esto.',
      'unavailable' => 'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
      'not-found' => 'No encontramos lo que buscas.',
      'deadline-exceeded' =>
        'El servidor tardó en responder. Inténtalo de nuevo.',
      _ => 'Algo salió mal. Inténtalo de nuevo.',
    };
  }
  const prefix = 'Exception: ';
  final text = error.toString();
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}

/// Errors our callables throw on purpose carry Spanish copy for the user;
/// anything else (INTERNAL, DEADLINE_EXCEEDED, function not deployed:
/// NOT_FOUND) is returned as-is so [userMessage] maps its code.
Object callableError(FirebaseFunctionsException e) {
  const intended = {
    'failed-precondition',
    'permission-denied',
    'invalid-argument',
    'unauthenticated',
    'not-found',
  };
  final msg = e.message;
  // Firebase's own messages are the bare code in capitals ("NOT_FOUND").
  if (intended.contains(e.code) && msg != null && msg != msg.toUpperCase()) {
    return Exception(msg);
  }
  return e;
}
