import 'package:clocky/models/stopwatch_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/stopwatch_screen.dart';
import 'bloc/stopwatch_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup notification channel before starting background service
  await setupNotificationChannel();

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

  // Create the notification channel
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

    // First check if the service is already running
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
    // Reset background operation preference if service fails to initialize
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
      content: "Stopwatch is active in the background",
    );
    service.setAutoStartOnBootMode(true);
  }

  final stopwatchManager = StopwatchManager();

  // Load persisted state when service starts
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
    // Save state before stopping
    await stopwatchManager.saveState();
    try {
      await service.stopSelf();
      debugPrint('Background Service: Service stopped successfully');
    } catch (e) {
      debugPrint('Background Service: Error stopping service: $e');
    }
  });

  // Add a periodic update loop
  try {
    debugPrint('Background Service: Starting main service loop');
    while (true) {
      // Always send the current total time (including accumulated time)
      final totalSeconds = stopwatchManager.totalElapsedSeconds;
      service.invoke('update', {'seconds': totalSeconds});

      // Periodically save state
      if (DateTime.now().second % 10 == 0) {
        // Save every 10 seconds
        await stopwatchManager.saveState();
      }

      await Future.delayed(Duration(milliseconds: 100));
    }
  } catch (e) {
    debugPrint('Background Service: Error in main loop: $e');
    // Save state before error
    await stopwatchManager.saveState();
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
