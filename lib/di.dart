import 'package:dio/dio.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/data/api/vipo_api.dart' as api;
import 'package:vipo/data/api_config.dart';
import 'package:vipo/data/services/logs_service.dart';
import 'package:vipo/data/services/notes_service.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/repositories/notes_repository.dart';

/// Single construction site for the entire dependency graph.
///
/// Everything is built bottom-up in the constructor, in dependency order:
/// `Dio` → generated API clients → services → repositories → BLoCs
/// (`LogsBloc` before `TimerBloc`, because `TimerBloc` dispatches `LogCreated`
/// events to the shared `LogsBloc`). No service locator, no `context.read<>()`
/// inside BLoCs — every dependency is constructor-injected here.
///
/// `main.dart` constructs one `AppDeps` and feeds the pre-built repositories
/// and BLoCs into `MultiRepositoryProvider` / `MultiBlocProvider`.
class AppDeps {
  AppDeps() {
    final dio = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(milliseconds: 5000),
      receiveTimeout: const Duration(milliseconds: 3000),
      contentType: 'application/json',
    ));

    final logsApi = api.LogsApi(dio);
    final notesApi = api.NotesApi(dio);

    _logsService = LogsService(logsApi);
    _notesService = NotesService(notesApi);

    _logsRepository = LogsRepository(_logsService);
    _notesRepository = NotesRepository(_notesService);

    _logsBloc = LogsBloc(_logsRepository);
    _timerBloc = TimerBloc(_logsBloc);
    _notesBloc = NotesBloc(_notesRepository);
  }

  late final LogsService _logsService;
  late final NotesService _notesService;
  late final LogsRepository _logsRepository;
  late final NotesRepository _notesRepository;
  late final LogsBloc _logsBloc;
  late final TimerBloc _timerBloc;
  late final NotesBloc _notesBloc;

  LogsRepository get logsRepository => _logsRepository;
  NotesRepository get notesRepository => _notesRepository;
  LogsBloc get logsBloc => _logsBloc;
  TimerBloc get timerBloc => _timerBloc;
  NotesBloc get notesBloc => _notesBloc;

  /// Closes all BLoCs. Repositories and services hold no resources to release.
  Future<void> dispose() async {
    await _logsBloc.close();
    await _timerBloc.close();
    await _notesBloc.close();
  }
}