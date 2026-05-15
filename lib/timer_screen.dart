import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'models/timer_mode.dart';
import 'widgets/donut_timer.dart';
import 'widgets/mode_switch.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  TimerMode _currentMode = TimerMode.work;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;
  bool _isComplete = false;

  // Background tracking
  DateTime? _backgroundTimestamp;
  int? _savedRemainingSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _currentMode.duration.inSeconds;
      _isRunning = false;
      _isComplete = false;
    });
  }

  void _toggleTimer() {
    if (_isComplete) {
      _resetTimer();
      return;
    }

    setState(() {
      _isRunning = !_isRunning;
    });

    if (_isRunning) {
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _onTimerComplete();
      }
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isComplete = true;
    });
    _triggerCompletion();
  }

  Future<void> _triggerCompletion() async {
    // Vibration (iOS only - macOS doesn't support)
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    }

    // Notification
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.show(
      id: 0,
      title: '${_currentMode.label} Complete',
      body: 'Time for ${_currentMode == TimerMode.work ? 'a break' : 'work'}!',
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
    );
  }

  void _changeMode(TimerMode mode) {
    if (mode == _currentMode) return;
    setState(() {
      _currentMode = mode;
    });
    _resetTimer();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            DonutTimer(
              remainingSeconds: _remainingSeconds,
              totalSeconds: _currentMode.duration.inSeconds,
              color: CupertinoDynamicColor.resolve(_currentMode.color, context),
              onTap: _toggleTimer,
              onLongPress: _resetTimer,
              isRunning: _isRunning,
            ),
            const SizedBox(height: 48),
            ModeSwitch(
              currentMode: _currentMode,
              onModeChanged: _changeMode,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}