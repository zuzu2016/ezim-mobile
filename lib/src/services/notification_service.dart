import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'ezim_push';
  static const String _channelName = 'EZIM Notifications';
  static const String _channelDesc = 'EZIM system and status notifications';

  /// Global navigator key so we can push routes from static context
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Callback invoked when a push is received (for badge refresh etc.)
  static VoidCallback? onPushReceived;

  /// Callback invoked when a notification is tapped (deep link route)
  static void Function(String route)? onNotificationTapped;

  static Future<void> init() async {
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('FCM permission error (non-critical): $e');
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDesc,
              importance: Importance.high,
              showBadge: true,
            ),
          );
    }
  }

  static Future<String?> getFcmToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('FCM token error: $e');
      return null;
    }
  }

  static Future<void> setupBackgroundHandler() async {
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }

  static void setupForegroundHandler(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(
          title: notification.title ?? 'EZIM',
          body: notification.body ?? '',
          payload: jsonEncode(message.data),
        );
      }
      onPushReceived?.call();
    });

    // Handle tap on notification when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateFromPayload(message.data);
    });

    // Check if app was opened from a terminated state via notification
    _fcm.getInitialMessage().then((message) {
      if (message != null) {
        _navigateFromPayload(message.data);
      }
    });
  }

  static Future<void> _backgroundHandler(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'EZIM',
        body: notification.body ?? '',
        payload: jsonEncode(message.data),
      );
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static void _handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(payload));
        _navigateFromPayload(data);
      } catch (_) {}
    }
  }

  static void _navigateFromPayload(Map<String, dynamic> data) {
    final url = data['url'] ?? data['reference_url'] ?? '';
    if (url.isNotEmpty && onNotificationTapped != null) {
      onNotificationTapped!(url);
    }
  }

  /// Update the app icon badge count.
  /// On Android, badge is driven by notification count on supported launchers.
  static Future<void> updateBadge(int count) async {
    try {
      if (count <= 0) {
        await _localNotifications.cancelAll();
      }
    } catch (e) {
      debugPrint('Badge update error: $e');
    }
  }

  /// Remove the app icon badge.
  static Future<void> removeBadge() async {
    try {
      await _localNotifications.cancelAll();
    } catch (_) {}
  }
}
