import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google using FirebaseAuth only
  Future<UserCredential> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();

      if (kIsWeb) {
        return await _auth.signInWithPopup(provider);
      }

      return await _auth.signInWithProvider(provider);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Deletes the signed-in Auth user (rollback of a half-finished registration).
  Future<void> deleteCurrentUser() async => await _auth.currentUser?.delete();

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'user-not-found':
        return 'No hay una cuenta con este correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Inténtalo más tarde.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'weak-password':
        return 'La contraseña es muy débil.';
      case 'operation-not-allowed':
        return 'El ingreso con correo no está habilitado.';
      case 'account-exists-with-different-credential':
        return 'Este correo ya está registrado con otro método de ingreso.';
      case 'credential-already-in-use':
        return 'Estas credenciales ya pertenecen a otra cuenta.';
      default:
        return 'No pudimos completar el ingreso (${e.code}). Inténtalo de nuevo.';
    }
  }
}
