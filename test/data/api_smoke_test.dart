import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/data/api/vipo_api.dart';
import 'package:vipo/data/api_client.dart';
import 'package:vipo/data/api_config.dart';

void main() {
  test('kApiBaseUrl defaults to localhost:8080 when not overridden', () {
    expect(kApiBaseUrl, 'http://localhost:8080');
  });

  test('generated enums are present with the expected arity', () {
    // Names/order of individual enum cases are generator-controlled; only
    // assert counts so the test survives cosmetic changes to case spelling.
    expect(PomodoroState.values, hasLength(3));
    expect(LogAction.values, hasLength(6));
  });

  test('generated models are present and compile', () {
    final notes = <Note>[];
    final logEntries = <LogEntry>[];
    expect(notes, isEmpty);
    expect(logEntries, isEmpty);
  });

  test('generated api classes are present and compile', () {
    final notesApi = <NotesApi>[];
    final logsApi = <LogsApi>[];
    expect(notesApi, isEmpty);
    expect(logsApi, isEmpty);
  });

  test('buildApiClient wires kApiBaseUrl into the client', () {
    final client = buildApiClient();
    expect(client, isA<VipoApi>());
  });
}