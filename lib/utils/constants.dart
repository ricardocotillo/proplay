import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class AppConstants {
  /// ProPlay support WhatsApp (country code + number, digits only), used by
  /// `wa.me` links, e.g. the "organizadores verificados" notice.
  static const String supportWhatsApp = '51960326190';

  static const String _googleMapsApiKeyAndroid =
      'AIzaSyAZY0zvn5s0I2Eh5aEGy06QelTsC2SeUYg';
  static const String _googleMapsApiKeyIOS =
      'AIzaSyCTO2hGJLMHgHUgIzO0MN_DJmexpvku43E';

  static String get googleMapsApiKey {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return _googleMapsApiKeyIOS;
      case TargetPlatform.android:
      default:
        return _googleMapsApiKeyAndroid;
    }
  }
}
