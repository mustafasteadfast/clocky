import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stopwatch_manager.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/foundation.dart';

// Events
abstract class StopwatchEvent {}

class StartResumeEvent extends StopwatchEvent {}

class ResetEvent extends StopwatchEvent {}

class BackgroundToggleEvent extends StopwatchEvent {
  final bool isEnabled;
  BackgroundToggleEvent(this.isEnabled);
}

// Event to handle app being closed with background mode disabled
class StopWhenAppClosedEvent extends StopwatchEvent {}

// States
abstract class StopwatchState {
  final int seconds;
  final bool isRunning;
  final bool isBackgroundEnabled;
  StopwatchState(this.seconds, this.isRunning, this.isBackgroundEnabled);
}

class StopwatchInitial extends StopwatchState {
  StopwatchInitial() : super(0, false, false);
}

class StopwatchRunning extends StopwatchState {
  StopwatchRunning(int seconds, bool isRunning, bool isBackgroundEnabled)
    : super(seconds, isRunning, isBackgroundEnabled);
}

// BLoC
class StopwatchBloc extends Bloc<StopwatchEvent, StopwatchState> {
  final StopwatchManager _stopwatchManager = StopwatchManager();
  final _service = FlutterBackgroundService();

  StopwatchBloc() : super(StopwatchInitial()) {
    _initialize();

    on<StartResumeEvent>((event, emit) async {
      if (state.isRunning) {
        _stopwatchManager.stop();
        if (state.isBackgroundEnabled) {
          _service.invoke('stopStopwatch');
        }
        emit(
          StopwatchRunning(
            _stopwatchManager.totalElapsedSeconds,
            false,
            state.isBackgroundEnabled,
          ),
        );
      } else {
        _stopwatchManager.start();
        if (state.isBackgroundEnabled) {
          _service.invoke('startStopwatch');
        }
        emit(
          StopwatchRunning(
            _stopwatchManager.totalElapsedSeconds,
            true,
            state.isBackgroundEnabled,
          ),
        );
      }
    });

    on<ResetEvent>((event, emit) async {
      _stopwatchManager.reset();
      if (state.isBackgroundEnabled) {
        _service.invoke('resetStopwatch');
      }
      emit(StopwatchRunning(0, false, state.isBackgroundEnabled));
    });

    on<BackgroundToggleEvent>((event, emit) async {
      try {
        debugPrint(
          'BackgroundToggleEvent: Attempting to ${event.isEnabled ? 'enable' : 'disable'} background service',
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('bgOperation', event.isEnabled);

        // Save the current state before enabling/disabling background
        await _stopwatchManager.saveState();

        bool newRunningState = state.isRunning;

        if (event.isEnabled) {
          // Enable background mode
          final isRunning = await _service.isRunning();
          debugPrint(
            'BackgroundToggleEvent: Service running status before enable: $isRunning',
          );
          if (!isRunning) {
            debugPrint('BackgroundToggleEvent: Starting service...');
            await _service.startService();
          }
          // Sync the current state with the background service
          if (state.isRunning) {
            _service.invoke('startStopwatch');
          }
        } else {
          // Disable background mode
          final isRunning = await _service.isRunning();
          debugPrint(
            'BackgroundToggleEvent: Service running status before disable: $isRunning',
          );

          // If the stopwatch is running, stop it first
          if (state.isRunning) {
            _stopwatchManager.stop();
            newRunningState = false;
          }

          if (isRunning) {
            debugPrint('BackgroundToggleEvent: Stopping service...');
            _service.invoke('stopService');
          }
        }

        emit(
          StopwatchRunning(
            _stopwatchManager.totalElapsedSeconds,
            newRunningState,
            event.isEnabled,
          ),
        );
        debugPrint(
          'BackgroundToggleEvent: Successfully ${event.isEnabled ? 'enabled' : 'disabled'} background service',
        );
      } catch (e) {
        debugPrint('BackgroundToggleEvent Error: $e');
        // Revert the background operation preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('bgOperation', !event.isEnabled);
        emit(
          StopwatchRunning(
            _stopwatchManager.totalElapsedSeconds,
            state.isRunning,
            !event.isEnabled,
          ),
        );
      }
    });

    on<StopWhenAppClosedEvent>((event, emit) async {
      debugPrint('StopwatchBloc: Processing StopWhenAppClosedEvent');
      if (state.isRunning && !state.isBackgroundEnabled) {
        _stopwatchManager.stop();
        await _stopwatchManager.saveState(); // Ensure state is saved
        emit(
          StopwatchRunning(
            _stopwatchManager.totalElapsedSeconds,
            false,
            state.isBackgroundEnabled,
          ),
        );
        debugPrint(
          'StopwatchBloc: Stopped stopwatch due to app closing with background mode off',
        );
      }
    });

    _service.on('update').listen((event) {
      if (event != null && state.isBackgroundEnabled) {
        final seconds = event['seconds'] as int;
        emit(
          StopwatchRunning(seconds, state.isRunning, state.isBackgroundEnabled),
        );
      }
    });
  }

  Future<void> _initialize() async {
    // Check if background service is already running
    final prefs = await SharedPreferences.getInstance();
    final bgEnabled = prefs.getBool('bgOperation') ?? false;

    if (bgEnabled) {
      final isServiceRunning = await _service.isRunning();
      if (isServiceRunning) {
        // Get updates from background service
        await _stopwatchManager.loadState();
        final isRunning = prefs.getBool('is_running') ?? false;
        emit(
          StopwatchRunning(
            _stopwatchManager.totalElapsedSeconds,
            isRunning,
            true,
          ),
        );
      } else {
        // Not running, load state from persistence
        await _stopwatchManager.loadState();
        final isRunning = prefs.getBool('is_running') ?? false;
        emit(
          StopwatchRunning(
            _stopwatchManager.totalElapsedSeconds,
            isRunning,
            false,
          ),
        );
      }
    } else {
      // Load local state if not using background
      await _stopwatchManager.loadState();
      final isRunning = prefs.getBool('is_running') ?? false;
      emit(
        StopwatchRunning(
          _stopwatchManager.totalElapsedSeconds,
          isRunning,
          false,
        ),
      );
    }
  }

  Stream<int> get secondsStream => Stream.periodic(
    Duration(milliseconds: 100),
    (_) => _stopwatchManager.totalElapsedSeconds,
  );
}
