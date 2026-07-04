// ignore_for_file: type=lint
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// Pomodoro timer state
enum PomodoroState {
          /// Pomodoro timer state
      @JsonValue(r'work')
      work(r'work'),
          /// Pomodoro timer state
      @JsonValue(r'short_break')
      shortBreak(r'short_break'),
          /// Pomodoro timer state
      @JsonValue(r'long_break')
      longBreak(r'long_break');

  const PomodoroState(this.value);

  final String value;

  @override
  String toString() => value;
}
