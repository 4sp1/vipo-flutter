import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/domain/result.dart';

void main() {
  group('Result.success', () {
    test('holds the supplied value and is a Success', () {
      const result = Result<int>.success(42);
      expect(result, isA<Success<int>>());
      expect((result as Success<int>).value, 42);
    });

    test('preserves generic type parameter for List<String>', () {
      final result = Result<List<String>>.success(const ['a', 'b']);
      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).value, ['a', 'b']);
    });

    test('void success accepts null and is a Success<void>', () {
      final result = Result<void>.success(null);
      expect(result, isA<Success<void>>());
    });
  });

  group('Result.failure', () {
    test('holds the supplied exception and is a Failure', () {
      const exception = FormatException('bad');
      const result = Result<String>.failure(exception);
      expect(result, isA<Failure<String>>());
      expect((result as Failure<String>).exception, same(exception));
    });

    test('exception class identity is preserved (LogCreateFailure)', () {
      const failure = LogCreateFailure('boom');
      final result = Result<String>.failure(failure);
      expect((result as Failure<String>).exception, isA<LogCreateFailure>());
    });
  });

  group('Sealed exhaustiveness', () {
    test('a Result is either Success or Failure and nothing else', () {
      Result<int> success = const Result<int>.success(1);
      Result<int> failing = const Result<int>.failure(LogRetrievalFailure('x'));

      String describe(Result<int> r) => switch (r) {
            Success(:final value) => 'ok=$value',
            Failure(:final exception) => 'err=$exception',
          };

      expect(describe(success), 'ok=1');
      expect(describe(failing), startsWith('err='));
    });
  });

  group('Domain failure toString', () {
    test('LogCreateFailure', () {
      expect(const LogCreateFailure('cannot create').toString(),
          'LogCreateFailure: cannot create');
    });
    test('LogRetrievalFailure', () {
      expect(const LogRetrievalFailure('cannot list').toString(),
          'LogRetrievalFailure: cannot list');
    });
    test('NoteCreateFailure', () {
      expect(const NoteCreateFailure('cannot create').toString(),
          'NoteCreateFailure: cannot create');
    });
    test('NoteRetrievalFailure', () {
      expect(const NoteRetrievalFailure('cannot get').toString(),
          'NoteRetrievalFailure: cannot get');
    });
  });

  group('Domain failures are Exceptions', () {
    test('every failure class implements Exception', () {
      expect(const LogCreateFailure(''), isA<Exception>());
      expect(const LogRetrievalFailure(''), isA<Exception>());
      expect(const NoteCreateFailure(''), isA<Exception>());
      expect(const NoteRetrievalFailure(''), isA<Exception>());
    });

    test('every failure exposes a non-final-but-immutable message field', () {
      expect(const LogCreateFailure('m1').message, 'm1');
      expect(const LogRetrievalFailure('m2').message, 'm2');
      expect(const NoteCreateFailure('m3').message, 'm3');
      expect(const NoteRetrievalFailure('m4').message, 'm4');
    });
  });
}