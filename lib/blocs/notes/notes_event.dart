import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/timer_mode.dart';

abstract class NotesEvent extends Equatable {
  const NotesEvent();
}

class NotesFetchRequested extends NotesEvent {
  const NotesFetchRequested();

  @override
  List<Object?> get props => [];
}

class NoteCreated extends NotesEvent {
  const NoteCreated({required this.content, required this.pomodoroState});

  final String content;
  final TimerMode pomodoroState;

  @override
  List<Object?> get props => [content, pomodoroState];
}

class NoteDeleted extends NotesEvent {
  const NoteDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}