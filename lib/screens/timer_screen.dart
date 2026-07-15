import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibration/vibration.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/blocs/timer/timer_event.dart';
import 'package:vipo/blocs/timer/timer_state.dart' as st;
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/notifications.dart' as notifications;
import 'package:vipo/screens/notes_screen.dart';
import 'package:vipo/widgets/donut_timer.dart';
import 'package:vipo/widgets/mode_switch.dart';

/// Pure view for the pomodoro timer.
///
/// Owns no state. Reads timer state from the ambient [TimerBloc] (provided in
/// `main.dart` via [AppDeps]) and dispatches user interactions back to it.
/// - [BlocBuilder] drives [DonutTimer]'s presentational props.
/// - [BlocSelector] selects the current [TimerMode] for [ModeSwitch].
/// - [BlocListener] fires vibration + local notification once on
///   [st.TimerComplete] (platform side effects live in the UI layer; BLoCs
///   never import platform packages — issue #9).
///
/// [StatelessWidget] is sufficient: [DonutTimer]'s animation is an implicit
/// `flutter_animate` wrapper that owns its ticker, so no [TickerProvider] is
/// required here.
class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  int _remainingSeconds(st.TimerState state) {
    return switch (state) {
      st.TimerInitial(:final duration) => duration,
      st.TimerRunInProgress(:final remainingSeconds) => remainingSeconds,
      st.TimerPaused(:final remainingSeconds) => remainingSeconds,
      st.TimerComplete() => 0,
    };
  }

  void _onDonutTap(BuildContext context) {
    final bloc = context.read<TimerBloc>();
    switch (bloc.state) {
      case st.TimerInitial():
        bloc.add(TimerStarted(bloc.state.mode));
      case st.TimerRunInProgress():
        bloc.add(TimerPaused());
      case st.TimerPaused():
        bloc.add(TimerResumed());
      case st.TimerComplete():
        bloc.add(TimerReset());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TimerBloc, st.TimerState>(
      listenWhen: (previous, current) =>
          current is st.TimerComplete && previous is! st.TimerComplete,
      listener: (context, state) async {
        final mode = state.mode;
        if (await Vibration.hasVibrator()) {
          Vibration.vibrate(duration: 500);
        }
        await notifications.show(
          title: '${mode.label} Complete',
          body: 'Time for ${mode == TimerMode.work ? 'a break' : 'work'}!',
        );
      },
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemBackground,
        navigationBar: CupertinoNavigationBar(
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const NotesScreen(),
                ),
              );
            },
            child: const Icon(CupertinoIcons.list_bullet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                BlocBuilder<TimerBloc, st.TimerState>(
                  builder: (context, state) {
                    return DonutTimer(
                      remainingSeconds: _remainingSeconds(state),
                      totalSeconds: state.mode.duration.inSeconds,
                      color:
                          CupertinoDynamicColor.resolve(state.mode.color, context),
                      onTap: () => _onDonutTap(context),
                      onLongPress: () =>
                          context.read<TimerBloc>().add(TimerReset()),
                      isRunning: state is st.TimerRunInProgress,
                    );
                  },
                ),
                const SizedBox(height: 48),
                BlocSelector<TimerBloc, st.TimerState, TimerMode>(
                  selector: (state) => state.mode,
                  builder: (context, mode) {
                    return ModeSwitch(
                      currentMode: mode,
                      onModeChanged: (newMode) =>
                          context.read<TimerBloc>().add(TimerModeChanged(newMode)),
                    );
                  },
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}