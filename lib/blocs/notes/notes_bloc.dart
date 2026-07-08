import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/notes_repository.dart';
import 'notes_event.dart';
import 'notes_state.dart';

class NotesBloc extends Bloc<NotesEvent, NotesState> {
  NotesBloc(this._notesRepository) : super(NotesInitial()) {
    on<NotesFetchRequested>(_onFetchRequested);
    on<NoteCreated>(_onNoteCreated);
    on<NoteDeleted>(_onNoteDeleted);
  }

  final NotesRepository _notesRepository;

  Future<void> _onFetchRequested(
    NotesFetchRequested event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoadInProgress());
    final result = await _notesRepository.getNotes();
    if (result is Success<List<Note>>) {
      emit(NotesLoadSuccess(result.value));
    } else if (result is Failure<List<Note>>) {
      emit(NotesLoadFailure(result.exception.toString()));
    }
  }

  Future<void> _onNoteCreated(
    NoteCreated event,
    Emitter<NotesState> emit,
  ) async {
    final note = Note(
      id: '',
      content: event.content,
      createdAt: DateTime.now(),
    );
    final result = await _notesRepository.createNote(note, event.pomodoroState);
    if (result is Success<Note>) {
      final currentNotes = state is NotesLoadSuccess
          ? (state as NotesLoadSuccess).notes
          : const <Note>[];
      emit(NotesLoadSuccess([result.value, ...currentNotes]));
    }
    // On failure: do not emit — state stays unchanged (see plan SN-6).
  }

  Future<void> _onNoteDeleted(
    NoteDeleted event,
    Emitter<NotesState> emit,
  ) async {
    final result = await _notesRepository.deleteNote(event.id);
    if (result is Success<void>) {
      final currentNotes = state is NotesLoadSuccess
          ? (state as NotesLoadSuccess).notes
          : const <Note>[];
      emit(NotesLoadSuccess(
        currentNotes.where((n) => n.id != event.id).toList(),
      ));
    }
    // On failure: do not emit — state stays unchanged (see plan SN-6).
  }
}