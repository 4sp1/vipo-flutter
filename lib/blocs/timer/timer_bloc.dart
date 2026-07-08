import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/logs/logs_event.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'timer_event.dart';
import 'timer_state.dart' as st;

class TimerBloc extends Bloc<TimerEvent, st.TimerState> {
  TimerBloc(this._logsBloc)
      : super(
          st.TimerInitial(
            TimerMode.work,
            TimerMode.work.duration.inSeconds,
          ),
        ) {
    on<TimerStarted>(_onStarted);
    on<TimerPaused>(_onPaused);
    on<TimerResumed>(_onResumed);
    on<TimerReset>(_onReset);
    on<TimerTicked>(_onTicked);
    on<TimerModeChanged>(_onModeChanged);
    on<TimerCompleted>(_onCompleted);
  }

  final LogsBloc _logsBloc;
  StreamSubscription<int>? _tickerSubscription;

  /// Starts (or restarts) a periodic 1-second stream that emits decreasing
  /// remaining-seconds values and feeds them back as [TimerTicked] events.
  /// Uses `.take(remainingSeconds)` so the stream auto-completes when the
  /// countdown reaches zero.
  void _startTicker({required int remainingSeconds}) {
    _tickerSubscription?.cancel();
    _tickerSubscription = Stream.periodic(
      const Duration(seconds: 1),
      (tickCount) => remainingSeconds - tickCount - 1,
    ).take(remainingSeconds).listen(
          (remaining) => add(TimerTicked(remaining)),
        );
  }

  /// Fire-and-forget: dispatches a [LogCreated] event to the injected
  /// [LogsBloc]. Failures in the log pipeline never affect timer state.
  void _dispatchLog(LogAction action, TimerMode mode) {
    _logsBloc.add(
      LogCreated(
        LogEntry(
          id: '',
          pomodoroState: mode,
          action: action,
          createdAt: DateTime.now(),
        ),
      ),
    );
  }

  void _onStarted(TimerStarted event, Emitter<st.TimerState> emit) {
    emit(st.TimerRunInProgress(event.mode, event.mode.duration.inSeconds));
    _startTicker(remainingSeconds: event.mode.duration.inSeconds);
    _dispatchLog(LogAction.start, event.mode);
  }

  void _onPaused(TimerPaused event, Emitter<st.TimerState> emit) {
    _tickerSubscription?.cancel();
    final current = state;
    if (current is st.TimerRunInProgress) {
      emit(st.TimerPaused(current.mode, current.remainingSeconds));
      _dispatchLog(LogAction.pause, current.mode);
    }
  }

  void _onResumed(TimerResumed event, Emitter<st.TimerState> emit) {
    final current = state;
    if (current is st.TimerPaused) {
      emit(st.TimerRunInProgress(current.mode, current.remainingSeconds));
      _startTicker(remainingSeconds: current.remainingSeconds);
      _dispatchLog(LogAction.resume, current.mode);
    }
  }

  void _onReset(TimerReset event, Emitter<st.TimerState> emit) {
    _tickerSubscription?.cancel();
    final mode = state.mode;
    emit(st.TimerInitial(mode, mode.duration.inSeconds));
    _dispatchLog(LogAction.reset, mode);
  }

  void _onModeChanged(TimerModeChanged event, Emitter<st.TimerState> emit) {
    _tickerSubscription?.cancel();
    emit(st.TimerInitial(event.mode, event.mode.duration.inSeconds));
    _dispatchLog(LogAction.select, event.mode);
  }

  void _onTicked(TimerTicked event, Emitter<st.TimerState> emit) {
    if (event.remainingSeconds <= 0) {
      add(TimerCompleted());
    } else {
      emit(st.TimerRunInProgress(state.mode, event.remainingSeconds));
    }
  }

  void _onCompleted(TimerCompleted event, Emitter<st.TimerState> emit) {
    _tickerSubscription?.cancel();
    emit(st.TimerComplete(state.mode));
    _dispatchLog(LogAction.expire, state.mode);
  }

  @override
  Future<void> close() {
    _tickerSubscription?.cancel();
    return super.close();
  }
}