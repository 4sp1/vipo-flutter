import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/blocs/timer/timer_state.dart' as st;
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/screens/timer_screen.dart';
import 'package:vipo/widgets/donut_timer.dart';

class MockLogsRepository extends Mock implements LogsRepository {}

void main() {
  late MockLogsRepository mockLogsRepository;
  late LogsBloc logsBloc;

  final fallbackEntry = LogEntry(
    id: '1',
    pomodoroState: TimerMode.work,
    action: LogAction.start,
    createdAt: DateTime(2025, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(fallbackEntry);
  });

  setUp(() {
    mockLogsRepository = MockLogsRepository();
    when(() => mockLogsRepository.createLog(any()))
        .thenAnswer((_) async => Result.success(fallbackEntry));
    logsBloc = LogsBloc(mockLogsRepository);
  });

  tearDown(() async {
    await logsBloc.close();
  });

  Widget pumpSubject() {
    return CupertinoApp(
      home: BlocProvider<TimerBloc>(
        create: (_) => TimerBloc(logsBloc),
        child: const TimerScreen(),
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
}