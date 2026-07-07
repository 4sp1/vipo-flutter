/// Domain mirror of the API's `LogAction` enum.
///
/// Kept free of any `lib/data/api/` import so the domain layer
/// never depends on generated code.
enum LogAction {
  start,
  pause,
  resume,
  reset,
  expire,
  select;
}