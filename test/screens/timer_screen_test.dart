import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/blocs/timer/timer_state.dart' as st;
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/repositories/notes_repository.dart';
import 'package:vipo/screens/notes_screen.dart';
import 'package:vipo/screens/timer_screen.dart';
import 'package:vipo/widgets/donut_timer.dart';

class MockLogsRepository extends Mock implements LogsRepository {}

class MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  late MockLogsRepository mockLogsRepository;
  late MockNotesRepository mockNotesRepository;
  late LogsBloc logsBloc;

  final fallbackEntry = LogEntry(
    id: '1',
    pomodoroState: TimerMode.work,
    action: LogAction.start,
    createdAt: DateTime(2025, 1, 1),
  );

  final testNote = Note(
    id: '1',
    content: 'hello',
    createdAt: DateTime(2025, 1, 1, 12, 0),
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

    mockNotesRepository = MockNotesRepository();
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));
    when(() => mockNotesRepository.createNote(any(), any()))
        .thenAnswer((_) async => Result.success(testNote));
  });

  Widget pumpSubject() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TimerBloc>(create: (_) => TimerBloc(logsBloc)),
        BlocProvider<NotesBloc>(create: (_) => NotesBloc(mockNotesRepository)),
      ],
      child: CupertinoApp(
        home: const TimerScreen(),
      ),
    );
  }

  testWidgets('renders initial work countdown 20:00 and tap-to-start hint',
      (tester) async {
    await tester.pumpWidget(pumpSubject());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('tap to start'), findsOneWidget);
    expect(find.byType(DonutTimer), findsOneWidget);
  });

  testWidgets(
      'tapping the donut in the initial state dispatches TimerStarted '
      'and the bloc emits TimerRunInProgress', (tester) async {
    await tester.pumpWidget(pumpSubject());
    await tester.pump(const Duration(milliseconds: 500));

    final bloc = tester.element(find.byType(TimerScreen)).read<TimerBloc>();
    expect(bloc.state, isA<st.TimerInitial>());

    await tester.tap(find.byType(DonutTimer));
    await tester.pump();
    await tester.pump();

    expect(bloc.state, isA<st.TimerRunInProgress>());
    expect(
      (bloc.state as st.TimerRunInProgress).mode,
      TimerMode.work,
    );
  });

  testWidgets('selecting Short Break dispatches TimerModeChanged '
      'and the bloc emits TimerInitial(shortBreak)', (tester) async {
    await tester.pumpWidget(pumpSubject());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Short Break'));
    await tester.pump();
    await tester.pump();

    final bloc = tester.element(find.byType(TimerScreen)).read<TimerBloc>();
    expect(bloc.state, isA<st.TimerInitial>());
    expect(
      (bloc.state as st.TimerInitial).mode,
      TimerMode.shortBreak,
    );
    expect(find.text('05:00'), findsOneWidget);
  });

  testWidgets(
      'tapping the notes button pushes NotesScreen onto the navigator',
      (tester) async {
    await tester.pumpWidget(pumpSubject());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NotesScreen), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.list_bullet));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NotesScreen), findsOneWidget);
  });
}