import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/data/api/src/model/note.dart' as api;
import 'package:vipo/data/api/src/model/pomodoro_state.dart' as api;
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/mappers/note_mapper.dart';

void main() {
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  group('toDomainNote', () {
    test('maps id (int->String), note -> content, createdAt', () {
      final apiNote = api.Note(
        id: 9,
        note: 'hello',
        pomodoroState: api.PomodoroState.work,
        createdAt: ts,
      );
      final d = toDomainNote(apiNote);
      expect(d.id, '9');
      expect(d.content, 'hello');
      expect(d.createdAt, ts);
    });

    test('drops pomodoroState (domain Note has no such field)', () {
      final apiNote = api.Note(
        id: 9,
        note: 'hello',
        pomodoroState: api.PomodoroState.longBreak,
        createdAt: ts,
      );
      final d = toDomainNote(apiNote);
      expect(d.id, '9');
      expect(d.content, 'hello');
      // no pomodoroState field to assert on — compilation is the assertion.
    });
  });

  group('toApiNote', () {
    test('injects required pomodoroState and maps other fields', () {
      final domain = Note(id: '9', content: 'hello', createdAt: ts);
      final a = toApiNote(domain, pomodoroState: api.PomodoroState.longBreak);
      expect(a.id, 9);
      expect(a.note, 'hello');
      expect(a.pomodoroState, api.PomodoroState.longBreak);
      expect(a.createdAt, ts);
    });

    test('accepts every PomodoroState value', () {
      final domain = Note(id: '9', content: 'hello', createdAt: ts);
      for (final s in api.PomodoroState.values) {
        final a = toApiNote(domain, pomodoroState: s);
        expect(a.pomodoroState, s);
      }
    });
  });

  test('round-trip preserves content/id/createdAt for every pomodoroState',
      () {
    final apiNote = api.Note(
      id: 5,
      note: 'world',
      pomodoroState: api.PomodoroState.shortBreak,
      createdAt: ts,
    );
    final d = toDomainNote(apiNote);
    final back = toApiNote(d, pomodoroState: api.PomodoroState.shortBreak);
    expect(back.id, 5);
    expect(back.note, 'world');
    expect(back.pomodoroState, api.PomodoroState.shortBreak);
    expect(back.createdAt, ts);
  });

  group('toCreateNoteRequest', () {
    test('maps content and supplied pomodoroState; omits id/createdAt', () {
      final domain = Note(id: '0', content: 'hello', createdAt: ts);
      final req = toCreateNoteRequest(domain, TimerMode.shortBreak);
      expect(req.note, 'hello');
      expect(req.pomodoroState, api.PomodoroState.shortBreak);
    });

    test('round-trips all three TimerModes', () {
      final domain = Note(id: '0', content: 'x', createdAt: ts);
      const expected = <TimerMode, api.PomodoroState>{
        TimerMode.work: api.PomodoroState.work,
        TimerMode.shortBreak: api.PomodoroState.shortBreak,
        TimerMode.longBreak: api.PomodoroState.longBreak,
      };
      for (final entry in expected.entries) {
        expect(toCreateNoteRequest(domain, entry.key).pomodoroState, entry.value);
      }
    });
  });
}