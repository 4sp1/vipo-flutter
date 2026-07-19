import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/blocs/timer/timer_event.dart';
import 'package:vipo/blocs/timer/timer_state.dart' as st;
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';

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

  tearDown(() {
    logsBloc.close();
  });

  group('TimerBloc', () {
    test('initial state is TimerInitial with work mode', () {
      final bloc = TimerBloc(logsBloc);
      expect(
        bloc.state,
        st.TimerInitial(TimerMode.work, TimerMode.work.duration.inSeconds),
      );
      bloc.close();
    });

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerRunInProgress] on TimerStarted and dispatches LogCreated(start)',
      build: () => TimerBloc(logsBloc),
      act: (bloc) => bloc.add(TimerStarted(TimerMode.work)),
      expect: () => [
        st.TimerRunInProgress(TimerMode.work, TimerMode.work.duration.inSeconds),
      ],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.start,
                ),
              ),
            )).called(1);
      },
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerRunInProgress] with decremented seconds on TimerTicked',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerRunInProgress(TimerMode.work, 1200),
      act: (bloc) => bloc.add(TimerTicked(1199)),
      expect: () => [st.TimerRunInProgress(TimerMode.work, 1199)],
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerComplete] on TimerTicked reaching zero and dispatches LogCreated(expire)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerRunInProgress(TimerMode.work, 1),
      act: (bloc) => bloc.add(TimerTicked(0)),
      expect: () => [st.TimerComplete(TimerMode.work)],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.expire,
                ),
              ),
            )).called(1);
      },
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerPaused] on TimerPaused and dispatches LogCreated(pause)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerRunInProgress(TimerMode.work, 1000),
      act: (bloc) => bloc.add(TimerPaused()),
      expect: () => [st.TimerPaused(TimerMode.work, 1000)],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.pause,
                ),
              ),
            )).called(1);
      },
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerRunInProgress] on TimerResumed and dispatches LogCreated(resume)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerPaused(TimerMode.work, 1000),
      act: (bloc) => bloc.add(TimerResumed()),
      expect: () => [st.TimerRunInProgress(TimerMode.work, 1000)],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.resume,
                ),
              ),
            )).called(1);
      },
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerInitial] on TimerReset and dispatches LogCreated(reset)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerRunInProgress(TimerMode.work, 1000),
      act: (bloc) => bloc.add(TimerReset()),
      expect: () => [
        st.TimerInitial(TimerMode.work, TimerMode.work.duration.inSeconds),
      ],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.reset,
                ),
              ),
            )).called(1);
      },
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerInitial] on TimerModeChanged and dispatches LogCreated(select)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerInitial(TimerMode.work, TimerMode.work.duration.inSeconds),
      act: (bloc) => bloc.add(TimerModeChanged(TimerMode.shortBreak)),
      expect: () => [
        st.TimerInitial(
          TimerMode.shortBreak,
          TimerMode.shortBreak.duration.inSeconds,
        ),
      ],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.select,
                ),
              ),
            )).called(1);
      },
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerComplete] on TimerCompleted and dispatches LogCreated(expire)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerRunInProgress(TimerMode.work, 500),
      act: (bloc) => bloc.add(const TimerCompleted()),
      expect: () => [st.TimerComplete(TimerMode.work)],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.expire,
                ),
              ),
            )).called(1);
      },
    );

    test('cancels the ticker StreamSubscription on close', () {
      fakeAsync((async) {
        final bloc = TimerBloc(logsBloc);

        bloc.add(TimerStarted(TimerMode.work));
        async.flushMicrotasks();

        final states = <st.TimerState>[];
        final sub = bloc.stream.listen(states.add);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(states.whereType<st.TimerRunInProgress>(), isNotEmpty);

        bloc.close();
        async.flushMicrotasks();

        final countBefore = states.length;
        async.elapse(const Duration(seconds: 40));
        async.flushMicrotasks();

        expect(states.length, countBefore);
        expect(states.whereType<st.TimerComplete>(), isEmpty);

        sub.cancel();
      });
    });
  });
}