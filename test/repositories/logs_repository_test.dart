import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/data/services/logs_service.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';

class MockLogsService extends Mock implements LogsService {}

void main() {
  late MockLogsService mockService;
  late LogsRepository repo;
  final ts = DateTime.utc(2026, 1, 2, 10, 0, 0);

  setUp(() {
    mockService = MockLogsService();
    repo = LogsRepository(mockService);
  });

  // Builds a DioException mirroring what the service would throw.
  DioException dioError(DioExceptionType type, {int? statusCode}) {
    final response = statusCode == null
        ? null
        : Response<void>(
            requestOptions: RequestOptions(path: '/logs'),
            statusCode: statusCode,
          );
    return DioException(
      requestOptions: RequestOptions(path: '/logs'),
      response: response,
      type: type,
      message: 'boom',
    );
  }

  LogEntry sampleEntry() => LogEntry(
        id: '1',
        pomodoroState: TimerMode.work,
        action: LogAction.start,
        createdAt: ts,
      );

  group('LogsRepository.createLog', () {
    test('returns Result.success wrapping the service-returned LogEntry',
        () async {
      final entry = sampleEntry();
      when(() => mockService.createLog(entry))
          .thenAnswer((_) async => entry);

      final result = await repo.createLog(entry);

      expect(result, isA<Success<LogEntry>>());
      expect((result as Success<LogEntry>).value, entry);
      verify(() => mockService.createLog(entry)).called(1);
    });

    test('returns Result.failure(LogCreateFailure) on connectionTimeout',
        () async {
      final entry = sampleEntry();
      when(() => mockService.createLog(entry)).thenThrow(
        dioError(DioExceptionType.connectionTimeout),
      );

      final result = await repo.createLog(entry);

      expect(result, isA<Failure<LogEntry>>());
      final failure = (result as Failure<LogEntry>).exception;
      expect(failure, isA<LogCreateFailure>());
      expect((failure as LogCreateFailure).message, contains('connectionTimeout'));
    });

    test('returns Result.failure(LogCreateFailure) on a 5xx badResponse',
        () async {
      final entry = sampleEntry();
      when(() => mockService.createLog(entry)).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 500),
      );

      final result = await repo.createLog(entry);

      expect(result, isA<Failure<LogEntry>>());
      final failure = (result as Failure<LogEntry>).exception;
      expect(failure, isA<LogCreateFailure>());
      expect((failure as LogCreateFailure).message, contains('500'));
    });

    test('returns Result.failure(LogCreateFailure) on a 400 badResponse',
        () async {
      final entry = sampleEntry();
      when(() => mockService.createLog(entry)).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 400),
      );

      final result = await repo.createLog(entry);

      expect(result, isA<Failure<LogEntry>>());
      expect((result as Failure<LogEntry>).exception, isA<LogCreateFailure>());
    });
  });

  group('LogsRepository.getLogs', () {
    test('returns Result.success wrapping the service-returned list',
        () async {
      final list = [sampleEntry()];
      when(() => mockService.getLogs()).thenAnswer((_) async => list);

      final result = await repo.getLogs();

      expect(result, isA<Success<List<LogEntry>>>());
      expect((result as Success<List<LogEntry>>).value, same(list));
      verify(() => mockService.getLogs()).called(1);
    });

    test('returns Result.success with an empty list when service returns []',
        () async {
      when(() => mockService.getLogs()).thenAnswer((_) async => const []);

      final result = await repo.getLogs();

      expect(result, isA<Success<List<LogEntry>>>());
      expect((result as Success<List<LogEntry>>).value, isEmpty);
    });

    test('returns Result.failure(LogRetrievalFailure) on receiveTimeout',
        () async {
      when(() => mockService.getLogs()).thenThrow(
        dioError(DioExceptionType.receiveTimeout),
      );

      final result = await repo.getLogs();

      expect(result, isA<Failure<List<LogEntry>>>());
      final failure = (result as Failure<List<LogEntry>>).exception;
      expect(failure, isA<LogRetrievalFailure>());
      expect((failure as LogRetrievalFailure).message,
          contains('receiveTimeout'));
    });

    test('returns Result.failure(LogRetrievalFailure) on 503 badResponse',
        () async {
      when(() => mockService.getLogs()).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 503),
      );

      final result = await repo.getLogs();

      expect(result, isA<Failure<List<LogEntry>>>());
      final failure = (result as Failure<List<LogEntry>>).exception;
      expect(failure, isA<LogRetrievalFailure>());
      expect((failure as LogRetrievalFailure).message, contains('503'));
    });
  });
}