import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class AppConstants {
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
