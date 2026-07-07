/// Result of an operation that can either succeed with a value or fail with
/// an [Exception]. Follows Flutter's `Result` design pattern:
/// <https://docs.flutter.dev/app-architecture/design-patterns/result>.
///
/// Repository methods return `Result<T>` instead of throwing, so callers
/// (BLoCs) can `switch` on success/failure without try-catch and without
/// ever touching transport-layer exceptions like `DioException`.
sealed class Result<T> {
  const Result();

  /// Creates a successful result holding [value].
  const factory Result.success(T value) = Success<T>;

  /// Creates a failure result holding [exception].
  const factory Result.failure(Exception exception) = Failure<T>;
}

/// The success variant of [Result]. Carries the returned [value].
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  String toString() => 'Success($value)';
}

/// The failure variant of [Result]. Carries the domain [exception]; never a
/// raw `DioException` — repositories normalize transport errors into the
/// domain failures defined below before wrapping them here.
final class Failure<T> extends Result<T> {
  const Failure(this.exception);

  final Exception exception;

  @override
  String toString() => 'Failure($exception)';
}

/// Creating a log entry on the server failed.
///
/// `LogsRepository.createLog` produces this when the underlying
/// `LogsService.createLog` throws a `DioException`.
class LogCreateFailure implements Exception {
  const LogCreateFailure(this.message);

  final String message;

  @override
  String toString() => 'LogCreateFailure: $message';
}

/// Reading log entries from the server failed.
///
/// `LogsRepository.getLogs` produces this when the underlying
/// `LogsService.getLogs` throws a `DioException`.
class LogRetrievalFailure implements Exception {
  const LogRetrievalFailure(this.message);

  final String message;

  @override
  String toString() => 'LogRetrievalFailure: $message';
}

/// Creating a note on the server failed.
///
/// `NotesRepository.createNote` produces this when the underlying
/// `NotesService.createNote` throws a `DioException`.
class NoteCreateFailure implements Exception {
  const NoteCreateFailure(this.message);

  final String message;

  @override
  String toString() => 'NoteCreateFailure: $message';
}

/// Reading or deleting a note on the server failed.
///
/// `NotesRepository.getNotes`, `NotesRepository.getNoteById`, and
/// `NotesRepository.deleteNote` produce this when the underlying
/// `NotesService` method throws a `DioException` — or, for the id-taking
/// methods, a `FormatException` from `int.parse` on a non-numeric id.
class NoteRetrievalFailure implements Exception {
  const NoteRetrievalFailure(this.message);

  final String message;

  @override
  String toString() => 'NoteRetrievalFailure: $message';
}