import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web_only;

/// Web-specific Google Sign-In button wrapper.
/// Uses the Google Identity Services SDK renderButton.
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
    // Use the renderButton method from google_sign_in_web package
    // This displays the official Google Identity Services button
    // The clientId is read from the meta tag in index.html
    return web_only.renderButton();
  }
}
