import 'dart:async';

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
    await _save(uid, token);
    return PushStatus.on;
  }

  /// Forget this browser (the permission stays granted in the browser).
  /// Also used on logout, so the next account on a shared browser doesn't
  /// inherit this one's pushes.
  Future<void> disable(String uid) async {
    stopRefreshSync();
    if (!supported) return;
    final token = await _token();
    if (token != null) await _tokenDoc(uid, token).delete();
    // ignore: deprecated_member_use
    await FirebaseMessaging.instance.deleteToken();
  }

  StreamSubscription<String>? _refresh;
  String? _lastToken;

  /// While push is on, a rotated browser token replaces the stored one;
  /// otherwise pushes would silently stop.
  Future<void> startRefreshSync(String uid) async {
    if (!supported) return;
    await _refresh?.cancel();
    _lastToken = await _token();
    // ignore: deprecated_member_use
    _refresh = FirebaseMessaging.instance.onTokenRefresh.listen((fresh) async {
      final old = _lastToken;
      _lastToken = fresh;
      await _save(uid, fresh);
      if (old != null && old != fresh) await _tokenDoc(uid, old).delete();
    });
  }

  void stopRefreshSync() {
    _refresh?.cancel();
    _refresh = null;
    _lastToken = null;
  }

  /// Pushes that arrive while a ProPlay tab is focused (the browser shows
  /// nothing then); the app shows them in-app.
  Stream<({String title, String body})> get foregroundMessages => !supported
      ? const Stream.empty()
      : FirebaseMessaging.onMessage
            .where((m) => m.notification != null)
            .map(
              (m) => (
                title: m.notification!.title ?? '',
                body: m.notification!.body ?? '',
              ),
            );

  Future<void> _save(String uid, String token) => _tokenDoc(uid, token).set({
    'createdAt': FieldValue.serverTimestamp(),
    'platform': 'web',
    'token': token,
  });

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
