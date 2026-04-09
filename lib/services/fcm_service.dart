import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles FCM token registration and foreground notification display.
///
/// Call [init] once after the user is authenticated. It:
///   1. Requests notification permission (Android 13+ / iOS).
///   2. Saves the current FCM token to Firestore under users/{uid}/fcmTokens.
///   3. Listens for token refreshes and keeps Firestore up to date.
///   4. Shows a local notification when a message arrives in the foreground.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const _channelId   = 'shared_tracker_notifications';
  static const _channelName = 'Shared Tracker';
  static const _channelDesc = 'Notifications when a member adds an expense to a shared tracker.';

  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Must be called once after Firebase is initialised and the user is logged in.
  Future<void> init() async {
    // Request permission (no-op on Android < 13)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Initialise local notifications for foreground display
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // Save the initial token
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);

    // Refresh listener — token can rotate at any time
    _messaging.onTokenRefresh.listen(_saveToken);

    // Show a local notification when the app is in the foreground
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            autoCancel: true,
          ),
        ),
      );
    });
  }

  Future<void> _saveToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      // Use the token itself as the document ID so duplicate saves are idempotent
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token)
          .set({'token': token, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('FcmService: failed to save token — $e');
    }
  }
}
