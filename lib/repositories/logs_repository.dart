import 'package:dio/dio.dart';
import 'package:vipo/data/services/logs_service.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/result.dart';

/// Single source of truth for log data — the only class the BLoC layer may
/// call to read or write logs. Wraps a single injected [LogsService] and
/// returns [Result]s so callers never see [DioException].
///
/// No business logic: every method delegates to exactly one service method
/// and maps any thrown [DioException] to a domain failure. The service is
/// the **only** data-layer dependency — this file does not import
/// `lib/data/api/` (generated code) and does not import any BLoC/UI file.
class LogsRepository {
  const LogsRepository(this._service);

  final LogsService _service;

  /// Creates a log entry on the server. Delegates to
  /// [LogsService.createLog]. Any [DioException] is normalized to a
  /// [LogCreateFailure] (the original `DioException` is not stored on the
  /// failure — only a short message is, per SN-4 of the plan).
  Future<Result<LogEntry>> createLog(LogEntry entry) async {
    try {
      return Result.success(await _service.createLog(entry));
    } on DioException catch (e) {
      return Result.failure(LogCreateFailure(_dioSummary(e)));
    }
  }

  /// Lists log entries from the server. Delegates to
  /// [LogsService.getLogs]. Any [DioException] is normalized to a
  /// [LogRetrievalFailure].
  Future<Result<List<LogEntry>>> getLogs() async {
    try {
      return Result.success(await _service.getLogs());
    } on DioException catch (e) {
      return Result.failure(LogRetrievalFailure(_dioSummary(e)));
    }
  }
}

/// Builds a short, transport-free summary string of a [DioException] so the
/// domain failure carries no `DioException` object reference. Duplicated in
/// `notes_repository.dart` deliberately (see SN-6 of the plan).
String _dioSummary(DioException e) {
  final code = e.response?.statusCode;
  return code == null ? e.type.name : '${e.type.name} (HTTP $code)';
}