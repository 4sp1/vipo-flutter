import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/timer_mode.dart';

abstract class TimerEvent extends Equatable {
  const TimerEvent();
}

class TimerStarted extends TimerEvent {
  const TimerStarted(this.mode);
  final TimerMode mode;

  @override
  List<Object?> get props => [mode];
}

class TimerPaused extends TimerEvent {
  const TimerPaused();

  @override
  List<Object?> get props => [];
}

class TimerResumed extends TimerEvent {
  const TimerResumed();

  @override
  List<Object?> get props => [];
}

class TimerReset extends TimerEvent {
  const TimerReset();

  @override
  List<Object?> get props => [];
}

class TimerTicked extends TimerEvent {
  const TimerTicked(this.remainingSeconds);
  final int remainingSeconds;

  @override
  List<Object?> get props => [remainingSeconds];
}

class TimerModeChanged extends TimerEvent {
  const TimerModeChanged(this.mode);
  final TimerMode mode;

  @override
  List<Object?> get props => [mode];
}

class TimerCompleted extends TimerEvent {
  const TimerCompleted();

  @override
  List<Object?> get props => [];
}