import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Mobile-specific Google Sign-In button wrapper.
/// Uses a custom OutlinedButton that calls authenticate().
class PlatformGoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool enabled;
  final GoogleSignIn googleSignIn;
  final void Function(String? errorMessage)? onSignInComplete;

  const PlatformGoogleSignInButton({
    super.key,
    this.onPressed,
    this.enabled = true,
    required this.googleSignIn,
    this.onSignInComplete,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled
          ? () async {
              try {
                await googleSignIn.authenticate();
                onSignInComplete?.call(null);
              } catch (e) {
                onSignInComplete?.call(e.toString());
              }
            }
          : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      icon: Image.asset(
        'assets/google.png',
        height: 24,
        width: 24,
      ),
      label: const Text('Inicia sesión con Google'),
    );
  }
}
