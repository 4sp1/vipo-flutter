import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/domain/models/note.dart';

void main() {
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  Note make({String id = '1', String content = 'x'}) => Note(
        id: id,
        content: content,
        createdAt: ts,
      );

  test('equality is value-based', () {
    expect(make(), equals(make()));
    expect(make().hashCode, make().hashCode);
  });

  test('different id is not equal', () {
    expect(make(id: '1'), isNot(equals(make(id: '2'))));
  });

  test('different content is not equal', () {
    expect(make(content: 'x'), isNot(equals(make(content: 'y'))));
  });

  test('different createdAt is not equal', () {
    final a = make();
    final b = Note(
      id: '1',
      content: 'x',
      createdAt: ts.add(const Duration(seconds: 1)),
    );
    expect(a, isNot(equals(b)));
  });

  test('toString includes id and content', () {
    final n = make(content: 'hello');
    expect(n.toString(), contains('hello'));
    expect(n.toString(), contains('id'));
  });
}