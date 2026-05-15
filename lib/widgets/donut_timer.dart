import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DonutTimer extends StatelessWidget {
  const DonutTimer({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.color,
    required this.onTap,
    required this.onLongPress,
    this.isRunning = false,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isRunning;

  String get _timeDisplay {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(280, 280),
              painter: _DonutPainter(
                progress: progress,
                color: color,
                strokeWidth: 12,
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .scale(begin: const Offset(0.95, 0.95), duration: 300.ms),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeDisplay,
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 2,
                  ),
                ),
                if (isRunning)
                  const Text(
                    'tap to pause',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  )
                else if (remainingSeconds < totalSeconds)
                  const Text(
                    'tap to resume',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  )
                else
                  const Text(
                    'tap to start',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = CupertinoColors.systemGrey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}