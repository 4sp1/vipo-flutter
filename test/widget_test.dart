import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/di.dart';
import 'package:vipo/main.dart';
import 'package:vipo/screens/timer_screen.dart';

void main() {
  testWidgets('VipoApp builds TimerScreen within the provider tree',
      (tester) async {
    final deps = AppDeps();
    await tester.pumpWidget(VipoApp(deps: deps));
    await tester.pumpAndSettle();
    expect(find.byType(TimerScreen), findsOneWidget);
  });
}