import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final prefs = await SharedPreferences.getInstance();
  final counter = prefs.getInt('counter_value') ?? 0;

  debugPrint(
    '@@@@@@@@@@@@@@@@@@@@@ Background Notification Received @@@@@@@@@@@@@@@@@@@@@@@@@@@',
  );
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
  debugPrint('Message ID: ${message.messageId}');
  debugPrint('From: ${message.from}');
  debugPrint('Sent Time: ${message.sentTime}');
  debugPrint('TTL: ${message.ttl}');
  debugPrint('🔔 Counter Value When Received: $counter 🔔');
  debugPrint('🔔 __________________________ 🔔');
}

class FirebaseMsg {
  final msgService = FirebaseMessaging.instance;

  initFCM() async {
    // Request notification permissions
    NotificationSettings settings = await msgService.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get and log the token
    String? token = await msgService.getToken();
    debugPrint("Firebase Messaging Token: $token");

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final prefs = await SharedPreferences.getInstance();
      final counter = prefs.getInt('counter_value') ?? 0;

      debugPrint(
        '@@@@@@@@@@@@@@@@@@@@@ Foreground Notification Received @@@@@@@@@@@@@@@@@@@@@@@@@@@',
      );
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');
      debugPrint('Message ID: ${message.messageId}');
      debugPrint('From: ${message.from}');
      debugPrint('Sent Time: ${message.sentTime}');
      debugPrint('TTL: ${message.ttl}');
      debugPrint('🔔 Counter Value When Received: $counter 🔔');
    });

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '@@@@@@@@@@@@@@@@@@@@@ Notification Tapped @@@@@@@@@@@@@@@@@@@@@@@@@@@',
      );
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');
    });

    // Handle initial notification when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint(
          '@@@@@@@@@@@@@@@@@@@@@ Initial Notification (App Terminated) @@@@@@@@@@@@@@@@@@@@@@@@@@@',
        );
        debugPrint('Title: ${message.notification?.title}');
        debugPrint('Body: ${message.notification?.body}');
        debugPrint('Data: ${message.data}');
      }
    });
  }
}
