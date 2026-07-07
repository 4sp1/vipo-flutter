import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/data/services/notes_service.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/notes_repository.dart';

class MockNotesService extends Mock implements NotesService {}

void main() {
  late MockNotesService mockService;
  late NotesRepository repo;
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  setUp(() {
    mockService = MockNotesService();
    repo = NotesRepository(mockService);
  });

  DioException dioError(DioExceptionType type, {int? statusCode}) {
    final response = statusCode == null
        ? null
        : Response<void>(
            requestOptions: RequestOptions(path: '/notes'),
            statusCode: statusCode,
          );
    return DioException(
      requestOptions: RequestOptions(path: '/notes'),
      response: response,
      type: type,
      message: 'boom',
    );
  }

  Note sampleNote() =>
      Note(id: '11', content: 'hello', createdAt: ts);

  group('NotesRepository.createNote', () {
    test('returns Result.success wrapping the service-returned Note',
        () async {
      final note = sampleNote();
      when(() => mockService.createNote(note, TimerMode.work))
          .thenAnswer((_) async => note);

      final result = await repo.createNote(note, TimerMode.work);

      expect(result, isA<Success<Note>>());
      expect((result as Success<Note>).value, note);
      verify(() => mockService.createNote(note, TimerMode.work)).called(1);
    });

    test('returns Result.failure(NoteCreateFailure) on 500 badResponse',
        () async {
      final note = sampleNote();
      when(() => mockService.createNote(note, TimerMode.shortBreak))
          .thenThrow(dioError(DioExceptionType.badResponse, statusCode: 500));

      final result = await repo.createNote(note, TimerMode.shortBreak);

      expect(result, isA<Failure<Note>>());
      final failure = (result as Failure<Note>).exception;
      expect(failure, isA<NoteCreateFailure>());
      expect((failure as NoteCreateFailure).message, contains('500'));
    });

    test('returns Result.failure(NoteCreateFailure) on sendTimeout',
        () async {
      final note = sampleNote();
      when(() => mockService.createNote(note, TimerMode.longBreak))
          .thenThrow(dioError(DioExceptionType.sendTimeout));

      final result = await repo.createNote(note, TimerMode.longBreak);

      expect(result, isA<Failure<Note>>());
      final failure = (result as Failure<Note>).exception;
      expect(failure, isA<NoteCreateFailure>());
      expect((failure as NoteCreateFailure).message, contains('sendTimeout'));
    });
  });

  group('NotesRepository.getNotes', () {
    test('returns Result.success wrapping the service-returned list',
        () async {
      final list = [sampleNote()];
      when(() => mockService.getNotes()).thenAnswer((_) async => list);

      final result = await repo.getNotes();

      expect(result, isA<Success<List<Note>>>());
      expect((result as Success<List<Note>>).value, same(list));
      verify(() => mockService.getNotes()).called(1);
    });

    test('returns Result.failure(NoteRetrievalFailure) on 502 badResponse',
        () async {
      when(() => mockService.getNotes()).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 502),
      );

      final result = await repo.getNotes();

      expect(result, isA<Failure<List<Note>>>());
      final failure = (result as Failure<List<Note>>).exception;
      expect(failure, isA<NoteRetrievalFailure>());
      expect((failure as NoteRetrievalFailure).message, contains('502'));
    });
  });

  group('NotesRepository.getNoteById', () {
    test('returns Result.success wrapping the service-returned Note',
        () async {
      final note = sampleNote();
      when(() => mockService.getNoteById('11'))
          .thenAnswer((_) async => note);

      final result = await repo.getNoteById('11');

      expect(result, isA<Success<Note>>());
      expect((result as Success<Note>).value, note);
      verify(() => mockService.getNoteById('11')).called(1);
    });

    test('returns Result.failure(NoteRetrievalFailure) on 404 badResponse',
        () async {
      when(() => mockService.getNoteById('11')).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 404),
      );

      final result = await repo.getNoteById('11');

      expect(result, isA<Failure<Note>>());
      final failure = (result as Failure<Note>).exception;
      expect(failure, isA<NoteRetrievalFailure>());
      expect((failure as NoteRetrievalFailure).message, contains('404'));
    });

    test('normalizes FormatException from a non-numeric id', () async {
      when(() => mockService.getNoteById('abc'))
          .thenThrow(const FormatException('Could not parse'));

      final result = await repo.getNoteById('abc');

      expect(result, isA<Failure<Note>>());
      final failure = (result as Failure<Note>).exception;
      expect(failure, isA<NoteRetrievalFailure>());
      expect((failure as NoteRetrievalFailure).message, contains('Invalid note id'));
    });
  });

  group('NotesRepository.deleteNote', () {
    test('returns Result<void> success when service returns normally',
        () async {
      when(() => mockService.deleteNote('5')).thenAnswer((_) async {});

      final result = await repo.deleteNote('5');

      expect(result, isA<Success<void>>());
      verify(() => mockService.deleteNote('5')).called(1);
    });

    test('returns Result.failure(NoteRetrievalFailure) on 500 badResponse',
        () async {
      when(() => mockService.deleteNote('5')).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 500),
      );

      final result = await repo.deleteNote('5');

      expect(result, isA<Failure<void>>());
      final failure = (result as Failure<void>).exception;
      expect(failure, isA<NoteRetrievalFailure>());
      expect((failure as NoteRetrievalFailure).message, contains('500'));
    });

    test('normalizes FormatException from a non-numeric id', () async {
      when(() => mockService.deleteNote('abc'))
          .thenThrow(const FormatException('Could not parse'));

      final result = await repo.deleteNote('abc');

      expect(result, isA<Failure<void>>());
      final failure = (result as Failure<void>).exception;
      expect(failure, isA<NoteRetrievalFailure>());
      expect((failure as NoteRetrievalFailure).message, contains('Invalid note id'));
    });
  });
}