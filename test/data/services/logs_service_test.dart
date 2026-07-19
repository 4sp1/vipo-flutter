import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/data/api/vipo_api.dart' as api;
import 'package:vipo/data/services/logs_service.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';

class MockLogsApi extends Mock implements api.LogsApi {}

void main() {
  late MockLogsApi mockApi;
  late LogsService service;
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  setUpAll(() {
    registerFallbackValue(
      api.CreateLogEntryRequest(
        action: api.LogAction.start,
        session: api.PomodoroState.work,
      ),
    );
  });

  setUp(() {
    mockApi = MockLogsApi();
    service = LogsService(mockApi);
  });

  Response<T> okResponse<T>(T data) => Response<T>(
        requestOptions: RequestOptions(path: '/any'),
        data: data,
        statusCode: 200,
      );

  group('LogsService.createLog', () {
    test('builds request, calls LogsApi.createLogEntry, returns mapped LogEntry',
        () async {
      final apiEntry = api.LogEntry(
        id: 42,
        action: api.LogAction.start,
        session: api.PomodoroState.work,
        timestamp: ts,
      );
      when(() => mockApi.createLogEntry(
              createLogEntryRequest: any(named: 'createLogEntryRequest')))
          .thenAnswer((_) async => okResponse<api.LogEntry>(apiEntry));

      final input = LogEntry(
        id: '0',
        pomodoroState: TimerMode.work,
        action: LogAction.start,
        createdAt: ts,
      );
      final result = await service.createLog(input);

      expect(result, isA<LogEntry>());
      expect(result.id, '42');
      expect(result.action, LogAction.start);
      expect(result.pomodoroState, TimerMode.work);
      expect(result.createdAt, ts);
      final captured = verify(
        () => mockApi.createLogEntry(
            createLogEntryRequest: captureAny(named: 'createLogEntryRequest')),
      ).captured.single as api.CreateLogEntryRequest;
      expect(captured.action, api.LogAction.start);
      expect(captured.session, api.PomodoroState.work);
      expect(captured.payload, isNull);
    });
  });

  group('LogsService.getLogs', () {
    test('calls LogsApi.listLogEntries with defaults and maps each entry',
        () async {
      final list = api.LogEntryList(entries: [
        api.LogEntry(
            id: 1,
            action: api.LogAction.start,
            session: api.PomodoroState.work,
            timestamp: ts),
        api.LogEntry(
            id: 2,
            action: api.LogAction.reset,
            session: api.PomodoroState.longBreak,
            timestamp: ts),
      ], total: 2);
      when(() => mockApi.listLogEntries()).thenAnswer(
          (_) async => okResponse<api.LogEntryList>(list));

      final result = await service.getLogs();

      expect(result, isA<List<LogEntry>>());
      expect(result.length, 2);
      expect(result[0].id, '1');
      expect(result[0].action, LogAction.start);
      expect(result[1].id, '2');
      expect(result[1].action, LogAction.reset);
      expect(result[1].pomodoroState, TimerMode.longBreak);
      verify(() => mockApi.listLogEntries()).called(1);
    });

    test('returns empty list when API returns null entries', () async {
      when(() => mockApi.listLogEntries()).thenAnswer(
          (_) async => okResponse<api.LogEntryList>(api.LogEntryList()));

      final result = await service.getLogs();

      expect(result, isEmpty);
    });
  });

  group('LogsService error propagation (DioException surfaces unswallowed)', () {
    DioException dioErr({int? statusCode}) {
      final response = statusCode == null
          ? null
          : Response<void>(
              requestOptions: RequestOptions(path: '/log'),
              statusCode: statusCode,
            );
      return DioException(
        requestOptions: RequestOptions(path: '/log'),
        response: response,
        type: DioExceptionType.badResponse,
        message: 'boom',
      );
    }

    test('createLog propagates DioException from LogsApi.createLogEntry',
        () async {
      when(() => mockApi.createLogEntry(
              createLogEntryRequest: any(named: 'createLogEntryRequest')))
          .thenThrow(dioErr(statusCode: 500));

      final input = LogEntry(
        id: '0',
        pomodoroState: TimerMode.work,
        action: LogAction.start,
        createdAt: ts,
      );

      await expectLater(
        service.createLog(input),
        throwsA(isA<DioException>()),
      );
      verify(() => mockApi.createLogEntry(
              createLogEntryRequest: any(named: 'createLogEntryRequest')))
          .called(1);
    });

    test('getLogs propagates DioException from LogsApi.listLogEntries',
        () async {
      when(() => mockApi.listLogEntries()).thenThrow(dioErr(statusCode: 503));

      await expectLater(
        service.getLogs(),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'statusCode', 503)),
      );
      verify(() => mockApi.listLogEntries()).called(1);
    });
  });
}