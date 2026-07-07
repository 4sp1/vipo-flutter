import 'package:dio/dio.dart';
import 'package:vipo/data/services/notes_service.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';

/// Single source of truth for note data — the only class the BLoC layer may
/// call to read or write notes. Wraps a single injected [NotesService] and
/// returns [Result]s so callers never see [DioException] or
/// [FormatException].
///
/// No business logic: every method delegates to exactly one service method
/// and maps any thrown [DioException] or [FormatException] to a domain
/// failure. The service is the **only** data-layer dependency — this file
/// does not import `lib/data/api/` (generated code) and does not import any
/// BLoC/UI file.
class NotesRepository {
  const NotesRepository(this._service);

  final NotesService _service;

  /// Creates a note on the server. Delegates to
  /// [NotesService.createNote]. [pomodoroState] is supplied by the caller
  /// because the domain [Note] deliberately omits it (see SN-1 of the
  /// plan), matching the service contract from issue #7. Any
  /// [DioException] is normalized to a [NoteCreateFailure].
  Future<Result<Note>> createNote(Note note, TimerMode pomodoroState) async {
    try {
      return Result.success(
        await _service.createNote(note, pomodoroState),
      );
    } on DioException catch (e) {
      return Result.failure(NoteCreateFailure(_dioSummary(e)));
    }
  }

  /// Lists notes from the server. Delegates to [NotesService.getNotes].
  /// Any [DioException] is normalized to a [NoteRetrievalFailure].
  Future<Result<List<Note>>> getNotes() async {
    try {
      return Result.success(await _service.getNotes());
    } on DioException catch (e) {
      return Result.failure(NoteRetrievalFailure(_dioSummary(e)));
    }
  }

  /// Fetches a single note by its string id. Delegates to
  /// [NotesService.getNoteById]. Any [DioException] is normalized to a
  /// [NoteRetrievalFailure]. A [FormatException] thrown by the service when
  /// `id` is non-numeric is likewise normalized to a [NoteRetrievalFailure]
  /// so callers never need try-catch (see SN-2 of the plan).
  Future<Result<Note>> getNoteById(String id) async {
    try {
      return Result.success(await _service.getNoteById(id));
    } on DioException catch (e) {
      return Result.failure(NoteRetrievalFailure(_dioSummary(e)));
    } on FormatException {
      return Result.failure(
        NoteRetrievalFailure('Invalid note id: "$id"'),
      );
    }
  }

  /// Deletes a note by its string id. Delegates to
  /// [NotesService.deleteNote]. Any [DioException] is normalized to a
  /// [NoteRetrievalFailure] — there is no `NoteDeleteFailure` (issue scope,
  /// see SN-3 of the plan); `NoteRetrievalFailure` covers deletion too.
  /// A [FormatException] from a non-numeric `id` is normalized to a
  /// [NoteRetrievalFailure] (see SN-2).
  Future<Result<void>> deleteNote(String id) async {
    try {
      await _service.deleteNote(id);
      return Result<void>.success(null);
    } on DioException catch (e) {
      return Result.failure(NoteRetrievalFailure(_dioSummary(e)));
    } on FormatException {
      return Result.failure(
        NoteRetrievalFailure('Invalid note id: "$id"'),
      );
    }
  }
}

/// Builds a short, transport-free summary string of a [DioException] so the
/// domain failure carries no `DioException` object reference. Duplicated in
/// `logs_repository.dart` deliberately (see SN-6 of the plan).
String _dioSummary(DioException e) {
  final code = e.response?.statusCode;
  return code == null ? e.type.name : '${e.type.name} (HTTP $code)';
}