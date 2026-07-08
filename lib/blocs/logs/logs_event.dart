import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/log_entry.dart';

abstract class LogsEvent extends Equatable {
  const LogsEvent();
}

class LogsFetchRequested extends LogsEvent {
  const LogsFetchRequested();

  @override
  List<Object?> get props => [];
}

class LogCreated extends LogsEvent {
  const LogCreated(this.entry);
  final LogEntry entry;

  @override
  List<Object?> get props => [entry];
}