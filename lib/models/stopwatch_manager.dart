import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StopwatchManager {
  static final StopwatchManager _instance = StopwatchManager._internal();
  final Stopwatch _stopwatch = Stopwatch();
  DateTime? _startTime;
  int _elapsedSeconds = 0;
  bool _wasRunning = false;

  factory StopwatchManager() {
    return _instance;
  }

  StopwatchManager._internal();

  Stopwatch get stopwatch => _stopwatch;

  // Get the total elapsed seconds, including any saved time
  int get totalElapsedSeconds =>
      _elapsedSeconds +
      (_stopwatch.isRunning ? _stopwatch.elapsed.inSeconds : 0);

  // Save the current state to persist across app restarts
  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('elapsed_seconds', totalElapsedSeconds);
    await prefs.setBool('is_running', _stopwatch.isRunning);
    if (_stopwatch.isRunning) {
      await prefs.setString('start_time', DateTime.now().toIso8601String());
    } else {
      await prefs.remove('start_time');
    }
    debugPrint(
      'StopwatchManager: Saved state - elapsed: $totalElapsedSeconds, running: ${_stopwatch.isRunning}',
    );
  }

  // Load the persisted state
  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _elapsedSeconds = prefs.getInt('elapsed_seconds') ?? 0;
    _wasRunning = prefs.getBool('is_running') ?? false;
    final startTimeStr = prefs.getString('start_time');
    final bgOperationEnabled = prefs.getBool('bgOperation') ?? false;

    if (startTimeStr != null) {
      _startTime = DateTime.parse(startTimeStr);
      final now = DateTime.now();
      final additionalSeconds = now.difference(_startTime!).inSeconds;
      _elapsedSeconds += additionalSeconds;
    }

    _stopwatch.reset();

    // Only auto-start if background operation is enabled and it was running
    if (_wasRunning && bgOperationEnabled) {
      _stopwatch.start();
      debugPrint(
        'StopwatchManager: Auto-starting stopwatch due to background mode being enabled',
      );
    } else if (_wasRunning && !bgOperationEnabled) {
      // If it was running but background mode is off, we need to save the stopped state
      debugPrint(
        'StopwatchManager: Not auto-starting stopwatch because background mode is disabled',
      );
      await prefs.setBool('is_running', false);
    }

    debugPrint(
      'StopwatchManager: Loaded state - elapsed: $_elapsedSeconds, was running: $_wasRunning, background enabled: $bgOperationEnabled',
    );
  }

  // Start the stopwatch and save the state
  void start() {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
      saveState();
    }
  }

  // Stop the stopwatch and save the state
  void stop() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _elapsedSeconds += _stopwatch.elapsed.inSeconds;
      _stopwatch.reset();
      saveState();
    }
  }

  // Reset the stopwatch and save the state
  void reset() {
    _stopwatch.stop();
    _stopwatch.reset();
    _elapsedSeconds = 0;
    saveState();
  }
}
