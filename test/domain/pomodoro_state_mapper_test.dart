import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/data/api/src/model/pomodoro_state.dart' as api;
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/mappers/pomodoro_state_mapper.dart';

void main() {
  group('toTimerMode', () {
    test('work -> work', () {
      expect(toTimerMode(api.PomodoroState.work), TimerMode.work);
    });
    test('short_break -> shortBreak', () {
      expect(toTimerMode(api.PomodoroState.shortBreak), TimerMode.shortBreak);
    });
    test('long_break -> longBreak', () {
      expect(toTimerMode(api.PomodoroState.longBreak), TimerMode.longBreak);
    });
  });

  group('toApiPomodoroState', () {
    test('work -> work', () {
      expect(toApiPomodoroState(TimerMode.work), api.PomodoroState.work);
    });
    test('shortBreak -> short_break', () {
      expect(toApiPomodoroState(TimerMode.shortBreak),
          api.PomodoroState.shortBreak);
    });
    test('longBreak -> long_break', () {
      expect(toApiPomodoroState(TimerMode.longBreak),
          api.PomodoroState.longBreak);
    });
  });

  test('round-trip preserves value for every mode', () {
    for (final mode in TimerMode.values) {
      expect(toTimerMode(toApiPomodoroState(mode)), mode);
    }
    for (final state in api.PomodoroState.values) {
      expect(toApiPomodoroState(toTimerMode(state)), state);
    }
  });
}