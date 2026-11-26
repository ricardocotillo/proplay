import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:proplay/utils/constants.dart';

/// Where this device stands on web push.
enum PushStatus { unsupported, off, on, blocked }

/// Web push tokens: permission, FCM token, and the `users/{uid}/fcmTokens`
/// doc the Cloud Functions read. I/O only.
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Web with a VAPID key set. Other platforms don't get push yet.
  bool get supported => kIsWeb && AppConstants.webPushVapidKey.isNotEmpty;

  Future<PushStatus> status(String uid) async {
    if (!supported) return PushStatus.unsupported;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    switch (settings.authorizationStatus) {
      case AuthorizationStatus.denied:
      case AuthorizationStatus.deniedPermanently:
        return PushStatus.blocked;
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        final token = await _token();
        if (token == null) return PushStatus.off;
        final doc = await _tokenDoc(uid, token).get();
        return doc.exists ? PushStatus.on : PushStatus.off;
      case AuthorizationStatus.notDetermined:
        return PushStatus.off;
    }
  }

  /// Ask permission, then register this browser. Returns the new status.
  Future<PushStatus> enable(String uid) async {
    if (!supported) return PushStatus.unsupported;
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied ||
        settings.authorizationStatus == AuthorizationStatus.deniedPermanently) {
      return PushStatus.blocked;
    }
    final token = await _token();
    if (token == null) return PushStatus.off;
    await _tokenDoc(
      uid,
      token,
    ).set({'createdAt': FieldValue.serverTimestamp(), 'platform': 'web'});
    return PushStatus.on;
  }

  /// Forget this browser (the permission stays granted in the browser).
  Future<void> disable(String uid) async {
    if (!supported) return;
    final token = await _token();
    if (token != null) await _tokenDoc(uid, token).delete();
    // ignore: deprecated_member_use
    await FirebaseMessaging.instance.deleteToken();
  }

  // ponytail: getToken is deprecated in firebase_messaging 17 in favor of
  // register() + onRegistered; it still works on web. Move when it is removed.
  // ignore: deprecated_member_use
  Future<String?> _token() => FirebaseMessaging.instance.getToken(
    vapidKey: AppConstants.webPushVapidKey,
  );

  DocumentReference<Map<String, dynamic>> _tokenDoc(String uid, String token) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token);
}
