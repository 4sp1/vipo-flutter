import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/di.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/repositories/notes_repository.dart';

void main() {
  group('AppDeps', () {
    late AppDeps deps;

    setUp(() {
      deps = AppDeps();
    });

    tearDown(() async {
      await deps.dispose();
    });

    test('constructs the full dependency graph without throwing', () {
      expect(deps, isA<AppDeps>());
    });

    test('exposes LogsRepository and NotesRepository instances', () {
      expect(deps.logsRepository, isA<LogsRepository>());
      expect(deps.notesRepository, isA<NotesRepository>());
    });

    test('exposes LogsBloc, TimerBloc, and NotesBloc instances', () {
      expect(deps.logsBloc, isA<LogsBloc>());
      expect(deps.timerBloc, isA<TimerBloc>());
      expect(deps.notesBloc, isA<NotesBloc>());
    });
  });
}