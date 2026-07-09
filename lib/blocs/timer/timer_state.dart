import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/timer_mode.dart';

sealed class TimerState extends Equatable {
  const TimerState();

  TimerMode get mode;
}

class TimerInitial extends TimerState {
  const TimerInitial(this.mode, this.duration);

  @override
  final TimerMode mode;
  final int duration;

  @override
  List<Object?> get props => [mode, duration];
}

class TimerRunInProgress extends TimerState {
  const TimerRunInProgress(this.mode, this.remainingSeconds);

  @override
  final TimerMode mode;
  final int remainingSeconds;

  @override
  List<Object?> get props => [mode, remainingSeconds];
}

class TimerPaused extends TimerState {
  const TimerPaused(this.mode, this.remainingSeconds);

  @override
  final TimerMode mode;
  final int remainingSeconds;

  @override
  List<Object?> get props => [mode, remainingSeconds];
}

class TimerComplete extends TimerState {
  const TimerComplete(this.mode);

  @override
  final TimerMode mode;

  @override
  List<Object?> get props => [mode];
}