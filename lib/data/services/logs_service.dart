import 'package:vipo/data/api/vipo_api.dart' as api;
import 'package:vipo/domain/mappers/log_entry_mapper.dart';
import 'package:vipo/domain/models/log_entry.dart';

/// Thin, stateless wrapper around the generated [api.LogsApi].
///
/// Every method delegates to exactly one generated API call and maps the
/// response into a domain [LogEntry]. `DioException` propagates untouched —
/// error normalization is the repository's responsibility (see #4).
class LogsService {
  const LogsService(this._logsApi);

  final api.LogsApi _logsApi;

  /// Creates a log entry on the server and returns the persisted domain copy.
  ///
  /// `entry.id` and `entry.createdAt` are ignored — the server assigns them.
  Future<LogEntry> createLog(LogEntry entry) async {
    final request = toCreateLogEntryRequest(entry);
    final response =
        await _logsApi.createLogEntry(createLogEntryRequest: request);
    return toDomainLogEntry(response.data!);
  }

  /// Lists log entries from the server using generated defaults
  /// (`limit = 50`, `offset = 0`).
  Future<List<LogEntry>> getLogs() async {
    final response = await _logsApi.listLogEntries();
    final entries = response.data?.entries ?? const <api.LogEntry>[];
    return entries.map(toDomainLogEntry).toList(growable: false);
  }
}