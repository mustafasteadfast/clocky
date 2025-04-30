import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final prefs = await SharedPreferences.getInstance();
  final counter = prefs.getInt('counter_value') ?? 0;

  final player =
      AudioPlayer()
        ..setReleaseMode(ReleaseMode.loop)
        ..setAudioContext(
          const AudioContext(
            android: AudioContextAndroid(
              audioMode: AndroidAudioMode.normal,
              audioFocus: AndroidAudioFocus.gain,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
            ),
          ),
        );

  debugPrint(
    '@@@@@@@@@@@@@@@@@@@@@ Background Notification Received @@@@@@@@@@@@@@@@@@@@@@@@@@@',
  );
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
  debugPrint('Counter: $counter');

  try {
    debugPrint('🔔 Playing alarm sound... 🔔');
    await player.play(AssetSource('Alarm Sound Effect.mp3'));

    // Update the counter in the existing background service from main.dart
    FlutterBackgroundService().invoke('updateCounter', {'counter': counter});

    await Future.delayed(const Duration(seconds: 10));
    debugPrint('🔔 Stopping alarm sound... 🔔');
    await player.stop();
    debugPrint('🔔 Alarm dismissed after 10 seconds! 🔔');
  } catch (e) {
    debugPrint('🔔 Error playing/stopping alarm: $e 🔔');
  } finally {
    await player.dispose();
  }
}

class FirebaseMsg {
  final msgService = FirebaseMessaging.instance;

  Future<void> initFCM() async {
    // Request notification permissions
    NotificationSettings settings = await msgService.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get and log the token
    String? token = await msgService.getToken();
    debugPrint("Firebase Messaging Token: $token");

    // Set up background message handler
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
      debugPrint('Counter: $counter');
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
