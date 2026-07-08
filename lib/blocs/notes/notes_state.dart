import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/note.dart';

abstract class NotesState extends Equatable {
  const NotesState();
}

class NotesInitial extends NotesState {
  const NotesInitial();

  @override
  List<Object?> get props => [];
}

class NotesLoadInProgress extends NotesState {
  const NotesLoadInProgress();

  @override
  List<Object?> get props => [];
}

class NotesLoadSuccess extends NotesState {
  const NotesLoadSuccess(this.notes);
  final List<Note> notes;

  @override
  List<Object?> get props => [notes];
}

class NotesLoadFailure extends NotesState {
  const NotesLoadFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}