/// Platform-specific Google Sign-In button.
/// On web, uses the Google Identity Services SDK renderButton.
/// On mobile, uses a custom OutlinedButton that calls authenticate().
library;

export 'google_sign_in_button_web.dart' if (dart.library.io) 'google_sign_in_button_mobile.dart';
