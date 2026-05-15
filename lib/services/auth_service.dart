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
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://proplayapp.com/_/auth/action',
        handleCodeInApp: true,
        androidPackageName: 'com.proplayapp.proplay',
        androidInstallApp: true,
        iOSBundleId: 'com.proplayapp.proplay',
      );
      await _auth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> confirmPasswordReset({
    required String oobCode,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(code: oobCode, newPassword: newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'credential-already-in-use':
        return 'This credential is already associated with a different account.';
      default:
        return 'Auth error (${e.code}): ${e.message ?? 'Please try again.'}';
    }
  }
}
