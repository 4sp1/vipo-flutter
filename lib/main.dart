import 'package:flutter/cupertino.dart';
import 'timer_screen.dart';
import 'notifications.dart' as notifications;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await notifications.initialize();

  runApp(const VipoApp());
}

class VipoApp extends StatelessWidget {
  const VipoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Vipo',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(brightness: Brightness.dark),
      home: TimerScreen(),
    );
  }
}
