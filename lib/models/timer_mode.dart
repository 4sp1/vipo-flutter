import 'package:flutter/cupertino.dart';

enum TimerMode {
  work(
    duration: Duration(minutes: 25),
    label: 'Work',
    color: CupertinoColors.systemRed,
  ),
  shortBreak(
    duration: Duration(minutes: 5),
    label: 'Short Break',
    color: CupertinoColors.systemGreen,
  ),
  longBreak(
    duration: Duration(minutes: 15),
    label: 'Long Break',
    color: CupertinoColors.systemBlue,
  );

  const TimerMode({
    required this.duration,
    required this.label,
    required this.color,
  });

  final Duration duration;
  final String label;
  final CupertinoDynamicColor color;
}