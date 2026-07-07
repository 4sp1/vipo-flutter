import 'package:vipo/data/api/src/model/pomodoro_state.dart' as api;
import 'package:vipo/domain/models/timer_mode.dart';

/// Converts the generated API enum `PomodoroState` to the domain `TimerMode`.
TimerMode toTimerMode(api.PomodoroState apiState) {
  switch (apiState) {
    case api.PomodoroState.work:
      return TimerMode.work;
    case api.PomodoroState.shortBreak:
      return TimerMode.shortBreak;
    case api.PomodoroState.longBreak:
      return TimerMode.longBreak;
  }
}

/// Converts the domain `TimerMode` to the generated API enum `PomodoroState`.
api.PomodoroState toApiPomodoroState(TimerMode mode) {
  switch (mode) {
    case TimerMode.work:
      return api.PomodoroState.work;
    case TimerMode.shortBreak:
      return api.PomodoroState.shortBreak;
    case TimerMode.longBreak:
      return api.PomodoroState.longBreak;
  }
}