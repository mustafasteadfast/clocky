import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bloc/stopwatch_bloc.dart';
import 'dart:math' as math;

class StopwatchScreen extends StatefulWidget {
  @override
  _StopwatchScreenState createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen>
    with WidgetsBindingObserver {
  bool _bgOperation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndLoadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final bloc = context.read<StopwatchBloc>();
      final currentState = bloc.state;

      if (!currentState.isBackgroundEnabled && currentState.isRunning) {
        debugPrint('App going to background - stopping stopwatch');
        bloc.add(StopWhenAppClosedEvent());
      }
    }
  }

  Future<void> _checkPermissionsAndLoadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bgOperation = prefs.getBool('bgOperation') ?? false;
    });
    if (!prefs.containsKey('permissionsRequested')) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Background Permission'),
              content: Text(
                'Allow this app to run in the background?\nFor continuous operation, please disable battery optimization in settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    prefs.setBool('permissionsRequested', true);
                    Navigator.pop(context);
                  },
                  child: Text('Yes'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('No'),
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Modern Stopwatch'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BlocBuilder<StopwatchBloc, StopwatchState>(
              builder: (context, state) {
                return StreamBuilder<int>(
                  stream: BlocProvider.of<StopwatchBloc>(context).secondsStream,
                  initialData: state.seconds,
                  builder: (context, snapshot) {
                    final seconds = snapshot.data ?? state.seconds;
                    return Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: AnalogClock(seconds: seconds),
                    );
                  },
                );
              },
            ),
            SizedBox(height: 20),
            BlocBuilder<StopwatchBloc, StopwatchState>(
              builder: (context, state) {
                // Update local _bgOperation to match bloc state
                if (_bgOperation != state.isBackgroundEnabled) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _bgOperation = state.isBackgroundEnabled;
                    });
                  });
                }

                return Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Background Operation',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        state.isBackgroundEnabled
                            ? 'Stopwatch will continue in background'
                            : 'Stopwatch will stop when app is closed',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      value: _bgOperation,
                      onChanged: (value) {
                        setState(() => _bgOperation = value);
                        context.read<StopwatchBloc>().add(
                          BackgroundToggleEvent(value),
                        );

                        // Show feedback message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Background operation enabled. Stopwatch will continue when app is closed.'
                                  : 'Background operation disabled. Stopwatch will stop when app is closed.',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor:
                                value
                                    ? Colors.green.shade900
                                    : Colors.red.shade900,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      activeColor: Colors.blueAccent,
                      activeTrackColor: Colors.blueAccent.withOpacity(0.5),
                      inactiveTrackColor: Colors.grey.shade800,
                      inactiveThumbColor: Colors.grey,
                    ),
                    if (state.isBackgroundEnabled && state.isRunning)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_active,
                              color: Colors.green,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Running in background mode',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildButton(
                  context,
                  text: BlocBuilder<StopwatchBloc, StopwatchState>(
                    builder:
                        (context, state) => Text(
                          state.isRunning ? 'Pause' : 'Start',
                          style: TextStyle(color: Colors.white),
                        ),
                  ),
                  onPressed:
                      () =>
                          context.read<StopwatchBloc>().add(StartResumeEvent()),
                ),
                SizedBox(width: 20),
                _buildButton(
                  context,
                  text: Text('Reset', style: TextStyle(color: Colors.white)),
                  onPressed:
                      () => context.read<StopwatchBloc>().add(ResetEvent()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required Widget text,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black.withOpacity(0.7),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 5,
      ),
      child: text,
    );
  }
}

class AnalogClock extends StatelessWidget {
  final int seconds;

  const AnalogClock({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ModernClockPainter(seconds: seconds),
      size: Size(250, 250),
    );
  }
}

class ModernClockPainter extends CustomPainter {
  final int seconds;

  ModernClockPainter({required this.seconds});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw a white background circle
    final backgroundPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw the markers/dots
    final markerPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.8)
          ..strokeWidth = 1;
    for (int i = 0; i < 60; i++) {
      final angle = i * math.pi / 30;
      final outerX = center.dx + radius * 0.95 * math.cos(angle);
      final outerY = center.dy + radius * 0.95 * math.sin(angle);
      final innerX = center.dx + radius * 0.85 * math.cos(angle);
      final innerY = center.dy + radius * 0.85 * math.sin(angle);
      if (i % 5 == 0) {
        canvas.drawLine(
          Offset(outerX, outerY),
          Offset(innerX, innerY),
          markerPaint..strokeWidth = 2,
        );
      } else {
        // Draw smaller dots for the rest
        final dotX = center.dx + radius * 0.9 * math.cos(angle);
        final dotY = center.dy + radius * 0.9 * math.sin(angle);
        canvas.drawCircle(Offset(dotX, dotY), 1, markerPaint);
      }
    }

    final totalSeconds = seconds;
    final minutes = totalSeconds ~/ 60;
    final secondsInMinute = totalSeconds % 60;

    final minuteAngle = (minutes % 60) * math.pi / 30 - math.pi / 2;
    final secondAngle = secondsInMinute * math.pi / 30 - math.pi / 2;

    // Draw minute hand (black with opacity)
    final minuteHandPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.7)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    final minuteHandLength = radius * 0.6;
    canvas.drawLine(
      center,
      Offset(
        center.dx + minuteHandLength * math.cos(minuteAngle),
        center.dy + minuteHandLength * math.sin(minuteAngle),
      ),
      minuteHandPaint,
    );

    // Draw second hand (black with opacity)
    final secondHandPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.9)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    final secondHandLength = radius * 0.85;
    canvas.drawLine(
      center,
      Offset(
        center.dx + secondHandLength * math.cos(secondAngle),
        center.dy + secondHandLength * math.sin(secondAngle),
      ),
      secondHandPaint,
    );

    // Draw center dot
    final centerPaint =
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerPaint);
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant ModernClockPainter oldDelegate) {
    return oldDelegate.seconds != seconds;
  }
}
