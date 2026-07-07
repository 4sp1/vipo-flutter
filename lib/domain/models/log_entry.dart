import 'log_action.dart';
import 'timer_mode.dart';

/// Domain representation of a pomodoro log entry.
///
/// Field mapping vs the generated `lib/data/api/.../log_entry.dart`:
///   id            (String)   <-  id          (int)
///   pomodoroState (TimerMode) <-  session     (PomodoroState)
///   action        (LogAction) <-  action      (LogAction)
///   createdAt     (DateTime) <-  timestamp   (DateTime)
///   _             <-           payload      (Object?)  // dropped
class LogEntry {
  const LogEntry({
    required this.id,
    required this.pomodoroState,
    required this.action,
    required this.createdAt,
  });

  final String id;
  final TimerMode pomodoroState;
  final LogAction action;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogEntry &&
          other.id == id &&
          other.pomodoroState == pomodoroState &&
          other.action == action &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, pomodoroState, action, createdAt);

  @override
  String toString() =>
      'LogEntry(id: $id, pomodoroState: $pomodoroState, action: $action, '
      'createdAt: $createdAt)';
}