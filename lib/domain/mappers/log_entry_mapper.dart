import 'package:vipo/data/api/src/model/log_entry.dart' as api;
import 'package:vipo/data/api/src/model/log_action.dart' as api;
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/mappers/pomodoro_state_mapper.dart';

LogAction _toDomainLogAction(api.LogAction a) {
  switch (a) {
    case api.LogAction.start:
      return LogAction.start;
    case api.LogAction.pause:
      return LogAction.pause;
    case api.LogAction.resume:
      return LogAction.resume;
    case api.LogAction.reset:
      return LogAction.reset;
    case api.LogAction.expire:
      return LogAction.expire;
    case api.LogAction.select:
      return LogAction.select;
  }
}

api.LogAction _toApiLogAction(LogAction a) {
  switch (a) {
    case LogAction.start:
      return api.LogAction.start;
    case LogAction.pause:
      return api.LogAction.pause;
    case LogAction.resume:
      return api.LogAction.resume;
    case LogAction.reset:
      return api.LogAction.reset;
    case LogAction.expire:
      return api.LogAction.expire;
    case LogAction.select:
      return api.LogAction.select;
  }
}

/// Converts the generated API `LogEntry` into the domain `LogEntry`.
///
/// Field mapping: id (int->String), session -> pomodoroState,
/// action -> action, timestamp -> createdAt. `payload` is dropped.
LogEntry toDomainLogEntry(api.LogEntry apiEntry) {
  return LogEntry(
    id: apiEntry.id.toString(),
    pomodoroState: toTimerMode(apiEntry.session),
    action: _toDomainLogAction(apiEntry.action),
    createdAt: apiEntry.timestamp,
  );
}

/// Converts the domain `LogEntry` into the generated API `LogEntry`.
///
/// `payload` is set to `null` (the API field is optional).
/// Throws `FormatException` if [domainEntry.id] is not a valid integer.
api.LogEntry toApiLogEntry(LogEntry domainEntry) {
  return api.LogEntry(
    id: int.parse(domainEntry.id),
    action: _toApiLogAction(domainEntry.action),
    session: toApiPomodoroState(domainEntry.pomodoroState),
    timestamp: domainEntry.createdAt,
    payload: null,
  );
}