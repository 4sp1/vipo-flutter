import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/logs/logs_event.dart';
import 'package:vipo/blocs/logs/logs_state.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';

class MockLogsRepository extends Mock implements LogsRepository {}

void main() {
  late MockLogsRepository mockLogsRepository;

  final testLogEntry = LogEntry(
    id: '1',
    pomodoroState: TimerMode.work,
    action: LogAction.start,
    createdAt: DateTime(2025, 1, 1),
  );

  setUp(() {
    mockLogsRepository = MockLogsRepository();
    registerFallbackValue(testLogEntry);
  });

  group('LogsBloc', () {
    test('initial state is LogsInitial', () {
      expect(LogsBloc(mockLogsRepository).state, LogsInitial());
    });

    blocTest<LogsBloc, LogsState>(
      'emits [LogsLoadInProgress, LogsLoadSuccess] on LogsFetchRequested success',
      build: () {
        when(() => mockLogsRepository.getLogs())
            .thenAnswer((_) async => Result.success([testLogEntry]));
        return LogsBloc(mockLogsRepository);
      },
      act: (bloc) => bloc.add(LogsFetchRequested()),
      expect: () => [LogsLoadInProgress(), LogsLoadSuccess([testLogEntry])],
    );

    blocTest<LogsBloc, LogsState>(
      'emits [LogsLoadInProgress, LogsLoadFailure] on LogsFetchRequested failure',
      build: () {
        when(() => mockLogsRepository.getLogs()).thenAnswer(
          (_) async => Result.failure(LogRetrievalFailure('connectionTimeout')),
        );
        return LogsBloc(mockLogsRepository);
      },
      act: (bloc) => bloc.add(LogsFetchRequested()),
      expect: () => [
        LogsLoadInProgress(),
        LogsLoadFailure('LogRetrievalFailure: connectionTimeout'),
      ],
    );

    blocTest<LogsBloc, LogsState>(
      'emits [LogsLoadSuccess with appended entry] on LogCreated success',
      build: () {
        when(() => mockLogsRepository.createLog(any()))
            .thenAnswer((_) async => Result.success(testLogEntry));
        return LogsBloc(mockLogsRepository);
      },
      seed: () => LogsLoadSuccess([]),
      act: (bloc) => bloc.add(LogCreated(testLogEntry)),
      expect: () => [LogsLoadSuccess([testLogEntry])],
    );

    blocTest<LogsBloc, LogsState>(
      'does not change state on LogCreated failure',
      build: () {
        when(() => mockLogsRepository.createLog(any())).thenAnswer(
          (_) async => Result.failure(LogCreateFailure('connectionTimeout')),
        );
        return LogsBloc(mockLogsRepository);
      },
      seed: () => LogsLoadSuccess([]),
      act: (bloc) => bloc.add(LogCreated(testLogEntry)),
      expect: () => <LogsState>[],
    );
  });
}