import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/data/api/vipo_api.dart' as api;
import 'package:vipo/data/services/notes_service.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';

class MockNotesApi extends Mock implements api.NotesApi {}

void main() {
  late MockNotesApi mockApi;
  late NotesService service;
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  setUpAll(() {
    registerFallbackValue(
      api.CreateNoteRequest(
        note: '',
        pomodoroState: api.PomodoroState.work,
      ),
    );
  });

  setUp(() {
    mockApi = MockNotesApi();
    service = NotesService(mockApi);
  });

  Response<T> okResponse<T>(T data) => Response<T>(
        requestOptions: RequestOptions(path: '/any'),
        data: data,
        statusCode: 200,
      );

  group('NotesService.createNote', () {
    test('builds request with content+TimerMode, calls NotesApi.createNote, '
        'returns mapped Note', () async {
      final apiNote = api.Note(
        id: 11,
        note: 'hello',
        pomodoroState: api.PomodoroState.work,
        createdAt: ts,
      );
      when(() =>
              mockApi.createNote(createNoteRequest: any(named: 'createNoteRequest')))
          .thenAnswer((_) async => okResponse<api.Note>(apiNote));

      final input = Note(id: '0', content: 'hello', createdAt: ts);
      final result = await service.createNote(input, TimerMode.work);

      expect(result, isA<Note>());
      expect(result.id, '11');
      expect(result.content, 'hello');
      expect(result.createdAt, ts);
      final captured = verify(
        () => mockApi.createNote(
            createNoteRequest: captureAny(named: 'createNoteRequest')),
      ).captured.single as api.CreateNoteRequest;
      expect(captured.note, 'hello');
      expect(captured.pomodoroState, api.PomodoroState.work);
    });
  });

  group('NotesService.getNotes', () {
    test('calls NotesApi.listNotes and maps each Note', () async {
      final list = api.NoteList(notes: [
        api.Note(
            id: 1,
            note: 'a',
            pomodoroState: api.PomodoroState.work,
            createdAt: ts),
        api.Note(
            id: 2,
            note: 'b',
            pomodoroState: api.PomodoroState.shortBreak,
            createdAt: ts),
      ], total: 2);
      when(() => mockApi.listNotes())
          .thenAnswer((_) async => okResponse<api.NoteList>(list));

      final result = await service.getNotes();

      expect(result, isA<List<Note>>());
      expect(result.length, 2);
      expect(result[0].id, '1');
      expect(result[0].content, 'a');
      expect(result[1].id, '2');
      expect(result[1].content, 'b');
      verify(() => mockApi.listNotes()).called(1);
    });

    test('returns empty list when API returns null notes', () async {
      when(() => mockApi.listNotes())
          .thenAnswer((_) async => okResponse<api.NoteList>(api.NoteList()));

      final result = await service.getNotes();

      expect(result, isEmpty);
    });
  });

  group('NotesService.getNoteById', () {
    test('parses String id to int and maps returned Note', () async {
      final apiNote = api.Note(
        id: 7,
        note: 'single',
        pomodoroState: api.PomodoroState.longBreak,
        createdAt: ts,
      );
      when(() => mockApi.getNote(id: any(named: 'id')))
          .thenAnswer((_) async => okResponse<api.Note>(apiNote));

      final result = await service.getNoteById('7');

      expect(result.id, '7');
      expect(result.content, 'single');
      verify(() => mockApi.getNote(id: 7)).called(1);
    });

    test('propagates FormatException when id is not an integer', () async {
      expect(() => service.getNoteById('not-a-number'),
          throwsA(isA<FormatException>()));
    });
  });

  group('NotesService.deleteNote', () {
    test('parses String id and calls NotesApi.deleteNote', () async {
      when(() => mockApi.deleteNote(id: any(named: 'id')))
          .thenAnswer((_) async => okResponse<void>(null));

      await service.deleteNote('5');

      verify(() => mockApi.deleteNote(id: 5)).called(1);
    });

    test('propagates FormatException when id is not an integer', () async {
      expect(() => service.deleteNote('abc'),
          throwsA(isA<FormatException>()));
    });
  });
}