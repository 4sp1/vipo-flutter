import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/domain/models/timer_mode.dart';

void main() {
  test('TimerMode has exactly three values work, shortBreak, longBreak', () {
    expect(TimerMode.values.map((m) => m.name).toList(), [
      'work',
      'shortBreak',
      'longBreak',
    ]);
  });

  test('each mode exposes duration, label, color', () {
    for (final mode in TimerMode.values) {
      expect(mode.duration, isA<Duration>());
      expect(mode.label, isA<String>());
      expect(mode.color, isNotNull);
    }
  });
}