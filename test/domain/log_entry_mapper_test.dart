import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/data/api/src/model/log_entry.dart' as api;
import 'package:vipo/data/api/src/model/log_action.dart' as api;
import 'package:vipo/data/api/src/model/pomodoro_state.dart' as api;
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/mappers/log_entry_mapper.dart';

void main() {
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  group('toDomainLogEntry', () {
    test('maps every field (id, session, action, timestamp)', () {
      final apiEntry = api.LogEntry(
        id: 42,
        action: api.LogAction.start,
        session: api.PomodoroState.work,
        timestamp: ts,
      );
      final d = toDomainLogEntry(apiEntry);
      expect(d.id, '42');
      expect(d.pomodoroState, TimerMode.work);
      expect(d.action, LogAction.start);
      expect(d.createdAt, ts);
    });

    test('drops payload (domain LogEntry has no payload field)', () {
      final apiEntry = api.LogEntry(
        id: 1,
        action: api.LogAction.reset,
        session: api.PomodoroState.longBreak,
        timestamp: ts,
        payload: {'some': 'data'},
      );
      final d = toDomainLogEntry(apiEntry);
      expect(d.id, '1');
      expect(d.pomodoroState, TimerMode.longBreak);
      expect(d.action, LogAction.reset);
    });

    test('maps every API LogAction case to a domain LogAction', () {
      for (final a in api.LogAction.values) {
        final entry = api.LogEntry(
          id: 1,
          action: a,
          session: api.PomodoroState.work,
          timestamp: ts,
        );
        expect(toDomainLogEntry(entry).action.name, a.name);
      }
    });

    test('maps every API PomodoroState case', () {
      for (final s in api.PomodoroState.values) {
        final entry = api.LogEntry(
          id: 1,
          action: api.LogAction.start,
          session: s,
          timestamp: ts,
        );
        expect(toDomainLogEntry(entry).pomodoroState, isA<TimerMode>());
      }
    });
  });

  group('toApiLogEntry', () {
    test('maps every field and sets payload to null', () {
      final domain = LogEntry(
        id: '42',
        pomodoroState: TimerMode.shortBreak,
        action: LogAction.pause,
        createdAt: ts,
      );
      final a = toApiLogEntry(domain);
      expect(a.id, 42);
      expect(a.session, api.PomodoroState.shortBreak);
      expect(a.action, api.LogAction.pause);
      expect(a.timestamp, ts);
      expect(a.payload, isNull);
    });

    test('round-trips all pomodoro states and all actions', () {
      for (final mode in TimerMode.values) {
        for (final action in LogAction.values) {
          final domain = LogEntry(
            id: '7',
            pomodoroState: mode,
            action: action,
            createdAt: ts,
          );
          final back = toDomainLogEntry(toApiLogEntry(domain));
          expect(back.id, '7');
          expect(back.pomodoroState, mode);
          expect(back.action, action);
          expect(back.createdAt, ts);
        }
      }
    });
  });

  group('toCreateLogEntryRequest', () {
    test('builds request from action and pomodoroState; omits id/createdAt/payload', () {
      final domain = LogEntry(
        id: '0',
        pomodoroState: TimerMode.shortBreak,
        action: LogAction.pause,
        createdAt: DateTime.utc(2026, 1, 2, 10, 0, 0),
      );
      final req = toCreateLogEntryRequest(domain);
      expect(req.action, api.LogAction.pause);
      expect(req.session, api.PomodoroState.shortBreak);
      expect(req.payload, isNull);
    });

    test('round-trips all six LogActions', () {
      for (final action in LogAction.values) {
        final domain = LogEntry(
          id: '7',
          pomodoroState: TimerMode.work,
          action: action,
          createdAt: ts,
        );
        expect(toCreateLogEntryRequest(domain).action.name, action.name);
      }
    });

    test('round-trips all three TimerModes', () {
      for (final mode in TimerMode.values) {
        final domain = LogEntry(
          id: '7',
          pomodoroState: mode,
          action: LogAction.start,
          createdAt: ts,
        );
        expect(toCreateLogEntryRequest(domain).session, isA<api.PomodoroState>());
      }
    });
  });
}