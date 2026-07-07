import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/domain/models/log_action.dart';

void main() {
  test('LogAction has exactly six values in spec order', () {
    expect(LogAction.values.map((e) => e.name).toList(), [
      'start',
      'pause',
      'resume',
      'reset',
      'expire',
      'select',
    ]);
  });

  test('every value is distinct', () {
    final names = LogAction.values.map((e) => e.name).toSet();
    expect(names.length, LogAction.values.length);
  });
}