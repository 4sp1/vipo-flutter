import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/notes/notes_event.dart';
import 'package:vipo/blocs/notes/notes_state.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/notes_repository.dart';

class MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  late MockNotesRepository mockNotesRepository;

  final testNote = Note(
    id: '1',
    content: 'hello',
    createdAt: DateTime(2025, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(testNote);
    registerFallbackValue(TimerMode.work);
    registerFallbackValue('');
  });

  setUp(() {
    mockNotesRepository = MockNotesRepository();
  });

  group('NotesBloc', () {
    test('initial state is NotesInitial', () {
      expect(NotesBloc(mockNotesRepository).state, NotesInitial());
    });

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoadInProgress, NotesLoadSuccess] on NotesFetchRequested success',
      build: () {
        when(() => mockNotesRepository.getNotes())
            .thenAnswer((_) async => Result.success([testNote]));
        return NotesBloc(mockNotesRepository);
      },
      act: (bloc) => bloc.add(NotesFetchRequested()),
      expect: () => [NotesLoadInProgress(), NotesLoadSuccess([testNote])],
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoadInProgress, NotesLoadFailure] on NotesFetchRequested failure',
      build: () {
        when(() => mockNotesRepository.getNotes()).thenAnswer(
          (_) async => Result.failure(NoteRetrievalFailure('badGateway')),
        );
        return NotesBloc(mockNotesRepository);
      },
      act: (bloc) => bloc.add(NotesFetchRequested()),
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadFailure('NoteRetrievalFailure: badGateway'),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoadSuccess with prepended note] on NoteCreated success',
      build: () {
        when(() => mockNotesRepository.createNote(any(), any()))
            .thenAnswer((_) async => Result.success(testNote));
        return NotesBloc(mockNotesRepository);
      },
      seed: () => NotesLoadSuccess([]),
      act: (bloc) => bloc.add(
        NoteCreated(content: 'hello', pomodoroState: TimerMode.work),
      ),
      expect: () => [NotesLoadSuccess([testNote])],
    );

    blocTest<NotesBloc, NotesState>(
      'does not change state on NoteCreated failure',
      build: () {
        when(() => mockNotesRepository.createNote(any(), any())).thenAnswer(
          (_) async => Result.failure(NoteCreateFailure('badGateway')),
        );
        return NotesBloc(mockNotesRepository);
      },
      seed: () => NotesLoadSuccess([]),
      act: (bloc) => bloc.add(
        NoteCreated(content: 'hello', pomodoroState: TimerMode.work),
      ),
      expect: () => <NotesState>[],
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoadSuccess without deleted note] on NoteDeleted success',
      build: () {
        when(() => mockNotesRepository.deleteNote(any()))
            .thenAnswer((_) async => Result<void>.success(null));
        return NotesBloc(mockNotesRepository);
      },
      seed: () => NotesLoadSuccess([testNote]),
      act: (bloc) => bloc.add(NoteDeleted('1')),
      expect: () => [NotesLoadSuccess([])],
    );

    blocTest<NotesBloc, NotesState>(
      'does not change state on NoteDeleted failure',
      build: () {
        when(() => mockNotesRepository.deleteNote(any())).thenAnswer(
          (_) async => Result<void>.failure(
            NoteRetrievalFailure('badGateway'),
          ),
        );
        return NotesBloc(mockNotesRepository);
      },
      seed: () => NotesLoadSuccess([testNote]),
      act: (bloc) => bloc.add(NoteDeleted('1')),
      expect: () => <NotesState>[],
    );
  });
}