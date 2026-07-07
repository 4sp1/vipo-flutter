import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/timer_mode.dart';

void main() {
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  LogEntry make({String id = '1'}) => LogEntry(
        id: id,
        pomodoroState: TimerMode.work,
        action: LogAction.start,
        createdAt: ts,
      );

  test('equality is value-based', () {
    expect(make(), equals(make()));
    expect(make().hashCode, make().hashCode);
  });

  test('different id is not equal', () {
    expect(make(id: '1'), isNot(equals(make(id: '2'))));
  });

  test('different pomodoroState is not equal', () {
    final a = make();
    final b = LogEntry(
      id: '1',
      pomodoroState: TimerMode.shortBreak,
      action: LogAction.start,
      createdAt: ts,
    );
    expect(a, isNot(equals(b)));
  });

  test('different action is not equal', () {
    final a = make();
    final b = LogEntry(
      id: '1',
      pomodoroState: TimerMode.work,
      action: LogAction.pause,
      createdAt: ts,
    );
    expect(a, isNot(equals(b)));
  });

  test('toString includes id and action', () {
    final e = make();
    expect(e.toString(), contains('id'));
    expect(e.toString(), contains('start'));
  });
}