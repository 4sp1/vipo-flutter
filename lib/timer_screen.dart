import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:vibration/vibration.dart';
import 'domain/models/timer_mode.dart';
import 'widgets/donut_timer.dart';
import 'widgets/mode_switch.dart';
import 'notifications.dart' as notifications;

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  TimerMode _currentMode = TimerMode.work;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    notifications.show(title: 'hi', body: 'there');
    _resetTimer();
  }

  @override
  void dispose() {
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
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 500);
    }

    // Notification
    await notifications.show(
      title: '${_currentMode.label} Complete',
      body: 'Time for ${_currentMode == TimerMode.work ? 'a break' : 'work'}!',
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
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              DonutTimer(
                remainingSeconds: _remainingSeconds,
                totalSeconds: _currentMode.duration.inSeconds,
                color: CupertinoDynamicColor.resolve(
                  _currentMode.color,
                  context,
                ),
                onTap: _toggleTimer,
                onLongPress: _resetTimer,
                isRunning: _isRunning,
              ),
              const SizedBox(height: 48),
              ModeSwitch(currentMode: _currentMode, onModeChanged: _changeMode),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
