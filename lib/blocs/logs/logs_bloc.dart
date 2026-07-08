import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'logs_event.dart';
import 'logs_state.dart';

class LogsBloc extends Bloc<LogsEvent, LogsState> {
  LogsBloc(this._logsRepository) : super(LogsInitial()) {
    on<LogsFetchRequested>(_onFetchRequested);
    on<LogCreated>(_onLogCreated);
  }

  final LogsRepository _logsRepository;

  Future<void> _onFetchRequested(
    LogsFetchRequested event,
    Emitter<LogsState> emit,
  ) async {
    emit(LogsLoadInProgress());
    final result = await _logsRepository.getLogs();
    if (result is Success<List<LogEntry>>) {
      emit(LogsLoadSuccess(result.value));
    } else if (result is Failure<List<LogEntry>>) {
      emit(LogsLoadFailure(result.exception.toString()));
    }
  }

  Future<void> _onLogCreated(
    LogCreated event,
    Emitter<LogsState> emit,
  ) async {
    final result = await _logsRepository.createLog(event.entry);
    if (result is Success<LogEntry>) {
      final currentEntries = state is LogsLoadSuccess
          ? (state as LogsLoadSuccess).entries
          : const <LogEntry>[];
      emit(LogsLoadSuccess([...currentEntries, result.value]));
    }
    // On failure: do not emit — state stays unchanged (see plan SN-6).
  }
}