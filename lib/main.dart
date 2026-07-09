import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/di.dart';
import 'package:vipo/notifications.dart' as notifications;
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/repositories/notes_repository.dart';
import 'package:vipo/screens/timer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await notifications.initialize();

  runApp(VipoApp(deps: AppDeps()));
}

class VipoApp extends StatelessWidget {
  const VipoApp({super.key, required this.deps});

  final AppDeps deps;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Vipo',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(brightness: Brightness.dark),
      home: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LogsRepository>.value(value: deps.logsRepository),
          RepositoryProvider<NotesRepository>.value(value: deps.notesRepository),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<LogsBloc>(create: (_) => deps.logsBloc),
            BlocProvider<TimerBloc>(create: (_) => deps.timerBloc),
            BlocProvider<NotesBloc>(create: (_) => deps.notesBloc),
          ],
          child: const TimerScreen(),
        ),
      ),
    );
  }
}