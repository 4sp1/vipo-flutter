import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/notes/notes_event.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/repositories/notes_repository.dart';
import 'package:vipo/screens/notes_screen.dart';

class MockLogsRepository extends Mock implements LogsRepository {}

class MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  late MockLogsRepository mockLogsRepository;
  late MockNotesRepository mockNotesRepository;
  late LogsBloc logsBloc;
  late TimerBloc timerBloc;
  late NotesBloc notesBloc;

  final testNote = Note(
    id: '1',
    content: 'hello',
    createdAt: DateTime(2025, 1, 1, 12, 0),
  );

  final fallbackEntry = LogEntry(
    id: '1',
    pomodoroState: TimerMode.work,
    action: LogAction.start,
    createdAt: DateTime(2025, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(fallbackEntry);
    registerFallbackValue(testNote);
    registerFallbackValue(TimerMode.work);
    registerFallbackValue('');
  });

  setUp(() {
    mockLogsRepository = MockLogsRepository();
    when(() => mockLogsRepository.createLog(any()))
        .thenAnswer((_) async => Result.success(fallbackEntry));
    logsBloc = LogsBloc(mockLogsRepository);
    timerBloc = TimerBloc(logsBloc);

    mockNotesRepository = MockNotesRepository();
    // Default stub used by any test that does not override getNotes().
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));

    addTearDown(() async {
      await logsBloc.close();
      await timerBloc.close();
    });
  });

  /// Constructs a [NotesBloc] against [mockNotesRepository] and registers
  /// tear-down to close it. Callers MUST set any `getNotes()` / `createNote()`
  /// / `deleteNote()` stubs BEFORE calling this, because [NotesBloc]
  /// self-dispatches the initial fetch in its constructor (issue #41).
  void makeNotesBloc() {
    notesBloc = NotesBloc(mockNotesRepository);
    addTearDown(() async => await notesBloc.close());
  }

  Widget pumpSubject() {
    return CupertinoApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<NotesBloc>.value(value: notesBloc),
          BlocProvider<TimerBloc>.value(value: timerBloc),
        ],
        child: const NotesScreen(),
      ),
    );
  }

  testWidgets('shows CupertinoActivityIndicator while notes are loading',
      (tester) async {
    final completer = Completer<Result<List<Note>>>();
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => await completer.future);
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    completer.complete(Result.success(<Note>[]));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('shows notes list on load success', (tester) async {
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success([testNote]));
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('shows empty-state message when notes list is empty',
      (tester) async {
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('No notes yet'), findsOneWidget);
  });

  testWidgets('shows error message and Retry button on load failure',
      (tester) async {
    when(() => mockNotesRepository.getNotes()).thenAnswer(
      (_) async => Result.failure(NoteRetrievalFailure('badGateway')),
    );
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('NoteRetrievalFailure'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'tapping Retry re-dispatches NotesFetchRequested and clears error',
      (tester) async {
    final callCount = <int>[];
    when(() => mockNotesRepository.getNotes()).thenAnswer((_) async {
      callCount.add(1);
      if (callCount.length == 1) {
        return Result.failure(NoteRetrievalFailure('badGateway'));
      }
      return Result.success(<Note>[]);
    });
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('No notes yet'), findsOneWidget);
    verify(() => mockNotesRepository.getNotes()).called(2);
  });

  testWidgets(
      'tapping + shows dialog, entering text, tapping Add dispatches NoteCreated',
      (tester) async {
    when(() => mockNotesRepository.createNote(any(), any()))
        .thenAnswer((_) async => Result.success(testNote));
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), 'hello');
    await tester.pump();

    await tester.tap(find.text('Add'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    verify(() => mockNotesRepository.createNote(any(), any())).called(1);
  });

  testWidgets(
      'tapping Cancel in the add note dialog does not create a note',
      (tester) async {
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(CupertinoTextField), 'hello');
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump();

    verifyNever(() => mockNotesRepository.createNote(any(), any()));
  });

  testWidgets('dispatching NoteDeleted removes a note from the list',
      (tester) async {
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success([testNote]));
    when(() => mockNotesRepository.deleteNote(any()))
        .thenAnswer((_) async => Result<void>.success(null));
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('hello'), findsOneWidget);

    notesBloc.add(NoteDeleted('1'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    verify(() => mockNotesRepository.deleteNote('1')).called(1);
    expect(find.text('hello'), findsNothing);
  });
}