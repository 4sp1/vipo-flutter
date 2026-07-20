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
    // Default stub so the constructor-time self-dispatch never hits an
    // unstubbed mock. Tests that need different data override this.
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));
  });

  group('NotesBloc', () {
    test('initial state is NotesInitial synchronously after construction', () {
      // The self-dispatched NotesFetchRequested is queued; it has not been
      // processed yet at the moment of this synchronous assertion.
      final bloc = NotesBloc(mockNotesRepository);
      addTearDown(bloc.close);
      expect(bloc.state, NotesInitial());
    });

    blocTest<NotesBloc, NotesState>(
      'self-dispatches NotesFetchRequested on construction (success)',
      build: () {
        when(() => mockNotesRepository.getNotes())
            .thenAnswer((_) async => Result.success([testNote]));
        return NotesBloc(mockNotesRepository);
      },
      // No `act`: the constructor's add(NotesFetchRequested()) is the act.
      act: null,
      wait: const Duration(milliseconds: 50),
      expect: () => [NotesLoadInProgress(), NotesLoadSuccess([testNote])],
    );

    blocTest<NotesBloc, NotesState>(
      'self-dispatches NotesFetchRequested on construction (failure)',
      build: () {
        when(() => mockNotesRepository.getNotes()).thenAnswer(
          (_) async => Result.failure(NoteRetrievalFailure('badGateway')),
        );
        return NotesBloc(mockNotesRepository);
      },
      act: null,
      wait: const Duration(milliseconds: 50),
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadFailure('NoteRetrievalFailure: badGateway'),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoadInProgress, NotesLoadSuccess, NotesLoadSuccess(prepended)] on NoteCreated success',
      build: () {
        when(() => mockNotesRepository.createNote(any(), any()))
            .thenAnswer((_) async => Result.success(testNote));
        return NotesBloc(mockNotesRepository);
      },
      // No `seed`: the self-dispatch owns the initial load.Expect the
      // self-dispatch emissions first, then the NoteCreated emission.
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(
        NoteCreated(content: 'hello', pomodoroState: TimerMode.work),
      ),
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadSuccess(<Note>[]),
        NotesLoadSuccess([testNote]),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'does not change state on NoteCreated failure (only self-dispatch emits)',
      build: () {
        when(() => mockNotesRepository.createNote(any(), any())).thenAnswer(
          (_) async => Result.failure(NoteCreateFailure('badGateway')),
        );
        return NotesBloc(mockNotesRepository);
      },
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(
        NoteCreated(content: 'hello', pomodoroState: TimerMode.work),
      ),
      // Self-dispatch emits NotesLoadInProgress + NotesLoadSuccess([]);
      // the failed NoteCreated emits nothing.
      expect: () => [NotesLoadInProgress(), NotesLoadSuccess(<Note>[])],
    );

    blocTest<NotesBloc, NotesState>(
      'emits NotesLoadSuccess without deleted note on NoteDeleted success',
      build: () {
        when(() => mockNotesRepository.getNotes())
            .thenAnswer((_) async => Result.success([testNote]));
        when(() => mockNotesRepository.deleteNote(any()))
            .thenAnswer((_) async => Result<void>.success(null));
        return NotesBloc(mockNotesRepository);
      },
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(NoteDeleted('1')),
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadSuccess([testNote]),
        NotesLoadSuccess([]),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'does not change state on NoteDeleted failure (only self-dispatch emits)',
      build: () {
        when(() => mockNotesRepository.getNotes())
            .thenAnswer((_) async => Result.success([testNote]));
        when(() => mockNotesRepository.deleteNote(any())).thenAnswer(
          (_) async => Result<void>.failure(
            NoteRetrievalFailure('badGateway'),
          ),
        );
        return NotesBloc(mockNotesRepository);
      },
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(NoteDeleted('1')),
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadSuccess([testNote]),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'Retry: re-dispatching NotesFetchRequested from NotesLoadFailure re-fetches',
      build: () {
        final callCount = <int>[];
        when(() => mockNotesRepository.getNotes()).thenAnswer((_) async {
          callCount.add(1);
          if (callCount.length == 1) {
            return Result.failure(NoteRetrievalFailure('badGateway'));
          }
          return Result.success(<Note>[]);
        });
        return NotesBloc(mockNotesRepository);
      },
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(NotesFetchRequested()),
      // First 2 emissions from constructor self-dispatch (in-progress →
      // failure). Next 2 from the explicit Retry dispatch in `act`
      // (in-progress → success). 4 emissions proves the double-fetch.
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadFailure('NoteRetrievalFailure: badGateway'),
        NotesLoadInProgress(),
        NotesLoadSuccess(<Note>[]),
      ],
    );
  });
}