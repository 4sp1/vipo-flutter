import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/log_entry.dart';

abstract class LogsState extends Equatable {
  const LogsState();
}

class LogsInitial extends LogsState {
  const LogsInitial();

  @override
  List<Object?> get props => [];
}

class LogsLoadInProgress extends LogsState {
  const LogsLoadInProgress();

  @override
  List<Object?> get props => [];
}

class LogsLoadSuccess extends LogsState {
  const LogsLoadSuccess(this.entries);
  final List<LogEntry> entries;

  @override
  List<Object?> get props => [entries];
}

class LogsLoadFailure extends LogsState {
  const LogsLoadFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}