import 'package:vipo/data/api/vipo_api.dart' as api;
import 'package:vipo/domain/mappers/note_mapper.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';

/// Thin, stateless wrapper around the generated [api.NotesApi].
///
/// Every method delegates to exactly one generated API call and maps the
/// response into a domain [Note]. `DioException` propagates untouched —
/// error normalization is the repository's responsibility (see #4).
class NotesService {
  const NotesService(this._notesApi);

  final api.NotesApi _notesApi;

  /// Creates a note on the server and returns the persisted domain copy.
  ///
  /// [pomodoroState] is supplied by the caller because the domain `Note`
  /// deliberately omits it (per #6 SN-2) while `CreateNoteRequest` requires
  /// it. `note.id` and `note.createdAt` are ignored — server-assigned.
  Future<Note> createNote(Note note, TimerMode pomodoroState) async {
    final request = toCreateNoteRequest(note, pomodoroState);
    final response = await _notesApi.createNote(createNoteRequest: request);
    return toDomainNote(response.data!);
  }

  /// Lists notes from the server using generated defaults (`limit = 50`).
  Future<List<Note>> getNotes() async {
    final response = await _notesApi.listNotes();
    final notes = response.data?.notes ?? const <api.Note>[];
    return notes.map(toDomainNote).toList(growable: false);
  }

  /// Fetches a single note by its string id (parsed server-side as int).
  Future<Note> getNoteById(String id) async {
    final response = await _notesApi.getNote(id: int.parse(id));
    return toDomainNote(response.data!);
  }

  /// Deletes a note by its string id (parsed server-side as int).
  Future<void> deleteNote(String id) async {
    await _notesApi.deleteNote(id: int.parse(id));
  }
}