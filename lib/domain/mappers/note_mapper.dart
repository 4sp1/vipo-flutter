import 'package:vipo/data/api/src/model/note.dart' as api;
import 'package:vipo/data/api/src/model/pomodoro_state.dart' as api;
import 'package:vipo/data/api/src/model/create_note_request.dart' as api;
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/mappers/pomodoro_state_mapper.dart';
import 'package:vipo/domain/models/timer_mode.dart';

/// Converts the generated API `Note` into the domain `Note`.
///
/// Field mapping: id (int->String), note -> content, createdAt -> createdAt.
/// The API's `pomodoroState` is intentionally dropped — see SN-2.
Note toDomainNote(api.Note apiNote) {
  return Note(
    id: apiNote.id.toString(),
    content: apiNote.note,
    createdAt: apiNote.createdAt,
  );
}

/// Converts the domain `Note` into the generated API `Note`.
///
/// [pomodoroState] is required because the generated `ApiNote` marks it
/// required, but the domain `Note` deliberately does not model it. The
/// caller supplies the contextual timer-mode at creation time.
/// Throws `FormatException` if [domainNote.id] is not a valid integer.
api.Note toApiNote(
  Note domainNote, {
  required api.PomodoroState pomodoroState,
}) {
  return api.Note(
    id: int.parse(domainNote.id),
    note: domainNote.content,
    pomodoroState: pomodoroState,
    createdAt: domainNote.createdAt,
  );
}

/// Builds the generated `CreateNoteRequest` from a domain `Note` plus the
/// contextual timer-mode. Only `note` (domain content) and `pomodoroState`
/// are carried over — the server assigns `id` and `createdAt`.
api.CreateNoteRequest toCreateNoteRequest(Note domainNote, TimerMode pomodoroState) {
  return api.CreateNoteRequest(
    note: domainNote.content,
    pomodoroState: toApiPomodoroState(pomodoroState),
  );
}