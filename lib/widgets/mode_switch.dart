import 'package:flutter/cupertino.dart';
import '../domain/models/timer_mode.dart';

class ModeSwitch extends StatelessWidget {
  const ModeSwitch({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  final TimerMode currentMode;
  final ValueChanged<TimerMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSegmentedControl<TimerMode>(
      groupValue: currentMode,
      onValueChanged: onModeChanged,
      children: {
        for (final mode in TimerMode.values)
          mode: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(mode.label),
          ),
      },
    );
  }
}