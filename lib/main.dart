import 'package:clocky/firebase_options.dart';
import 'package:clocky/models/stopwatch_manager.dart';
import 'package:clocky/services/firebase_msg.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Add this for API calls
import 'dart:async'; // Add this for Timer
import 'screens/stopwatch_screen.dart';
import 'bloc/stopwatch_bloc.dart';

// Add notification listener
void setupNotificationListener() {
  FlutterLocalNotificationsPlugin().initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final prefs = await SharedPreferences.getInstance();
      final counter = prefs.getInt('counter_value') ?? 0;
      debugPrint('🔔 Notification Received! Counter was at: $counter 🔔');
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupNotificationChannel();
  setupNotificationListener();

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("9f765128-330a-4140-a7fc-95c4fe665fac");

  OneSignal.Notifications.requestPermission(true);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseMsg().initFCM();

  try {
    await initializeBackgroundService();
  } catch (e) {
    debugPrint('Failed to initialize background service: $e');
  }
  runApp(StopwatchApp());
}

Future<void> setupNotificationChannel() async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();

  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  const notificationChannelId = 'clocky_notification_channel';

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          notificationChannelId,
          'Clocky Service',
          description: 'Keeps the stopwatch running in background',
          importance: Importance.low,
        ),
      );
}

Future<void> initializeBackgroundService() async {
  try {
    final service = FlutterBackgroundService();

    const notificationChannelId = 'clocky_notification_channel';

    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Clocky',
        initialNotificationContent: 'Stopwatch Service Running',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: (_) => true,
        autoStart: false,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final bgEnabled = prefs.getBool('bgOperation') ?? false;
    if (bgEnabled) {
      await service.startService();
    }
  } catch (e) {
    debugPrint('Background service configuration failed: $e');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bgOperation', false);
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  debugPrint('Background Service: onStart called');

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Clocky Running",
      content: "Stopwatch, Counter, and API calls active in the background",
    );
    service.setAutoStartOnBootMode(true);
  }

  final stopwatchManager = StopwatchManager();
  final prefs = await SharedPreferences.getInstance();
  int counter = prefs.getInt('counter_value') ?? 0;
  String? lastUpdateStr = prefs.getString('counter_last_update');
  DateTime lastUpdate =
      lastUpdateStr != null ? DateTime.parse(lastUpdateStr) : DateTime.now();

  await stopwatchManager.loadState();
  debugPrint(
    'Background Service: Loaded stopwatch state: elapsed=${stopwatchManager.totalElapsedSeconds}s',
  );

  // Handle commands from the app
  service.on('startStopwatch').listen((event) {
    debugPrint('Background Service: Received startStopwatch command');
    stopwatchManager.start();
  });

  service.on('stopStopwatch').listen((event) {
    debugPrint('Background Service: Received stopStopwatch command');
    stopwatchManager.stop();
  });

  service.on('resetStopwatch').listen((event) {
    debugPrint('Background Service: Received resetStopwatch command');
    stopwatchManager.reset();
  });

  service.on('stopService').listen((event) async {
    debugPrint('Background Service: Received stop service request');
    await stopwatchManager.saveState();
    await prefs.setInt('counter_value', counter);
    await prefs.setString('counter_last_update', lastUpdate.toIso8601String());
    try {
      await service.stopSelf();
      debugPrint('Background Service: Service stopped successfully');
    } catch (e) {
      debugPrint('Background Service: Error stopping service: $e');
    }
  });

  // Periodic API calls every 10 seconds
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    debugPrint('🚀 Starting API call at ${DateTime.now()} 🚀');
    try {
      debugPrint(
        '🌐 Hitting API: http://192.168.10.249:7777/api/v1/brand-insert 🌐',
      );
      debugPrint('📤 Sending data: {"counter": $counter} 📤');
      debugPrint('🔍 Checking network connectivity... 🔍');
      // Optional: Add connectivity check if using connectivity_plus package
      final response = await http
          .get(
            Uri.parse('http://192.168.10.249:7777/api/v1/brand-insert'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('⏰ API call timed out after 10 seconds ⏰');
              throw TimeoutException('API call timed out');
            },
          );
      debugPrint('✅ API Response Status: ${response.statusCode} ✅');
      debugPrint('📡 API Response Body: ${response.body} 📡');

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Clocky Running 🎉",
          content: "Last API success: ${DateTime.now()} - Counter: $counter",
        );
      }
    } catch (e) {
      debugPrint('❌ API Error: $e ❌');
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Clocky Running 😢",
          content: "API failed at ${DateTime.now()} - Counter: $counter",
        );
      }
    }
    debugPrint('🏁 API call finished at ${DateTime.now()} 🏁');
  });

  // Existing counter and stopwatch update loop
  try {
    debugPrint('Background Service: Starting main service loop');
    while (true) {
      final now = DateTime.now();
      final difference = now.difference(lastUpdate).inSeconds;
      if (difference >= 2) {
        counter = (counter + 1) % 101;
        if (counter == 0) counter = 1;
        lastUpdate = now;
        await prefs.setInt('counter_value', counter);
        await prefs.setString(
          'counter_last_update',
          lastUpdate.toIso8601String(),
        );
        debugPrint('Background Service: Counter value: $counter');
      }

      final totalSeconds = stopwatchManager.totalElapsedSeconds;
      service.invoke('update', {'seconds': totalSeconds, 'counter': counter});

      if (DateTime.now().second % 10 == 0) {
        await stopwatchManager.saveState();
      }

      await Future.delayed(Duration(milliseconds: 100));
    }
  } catch (e) {
    debugPrint('Background Service: Error in main loop: $e');
    await stopwatchManager.saveState();
    await prefs.setInt('counter_value', counter);
    await prefs.setString('counter_last_update', lastUpdate.toIso8601String());
    await service.stopSelf();
  }
}

class StopwatchApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StopwatchBloc(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Clocky',
        theme: ThemeData(
          primaryColor: Colors.black,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: StopwatchScreen(),
      ),
    );
  }
}
