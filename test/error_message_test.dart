import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/error_message.dart';

void main() {
  test('strips the Exception prefix', () {
    expect(
      userMessage(Exception('Este evento ya está lleno.')),
      'Este evento ya está lleno.',
    );
  });

  test('plain strings pass through', () {
    expect(userMessage('Contraseña incorrecta.'), 'Contraseña incorrecta.');
  });

  test('Firebase codes become Spanish', () {
    expect(
      userMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      'No tienes permiso para hacer esto.',
    );
    expect(
      userMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'aborted'),
      ),
      'Algo salió mal. Inténtalo de nuevo.',
    );
  });
}
