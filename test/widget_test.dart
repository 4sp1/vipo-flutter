import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/di.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/main.dart';
import 'package:vipo/repositories/notes_repository.dart';
import 'package:vipo/screens/timer_screen.dart';

class _MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  testWidgets('VipoApp builds TimerScreen within the provider tree',
      (tester) async {
    // NotesBloc self-dispatches its fetch in the constructor (issue #41).
    // Inject a mock notes repository so no real HTTP is made from the smoke
    // test.
    final notesRepository = _MockNotesRepository();
    when(() => notesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));

    final deps = AppDeps(notesRepository: notesRepository);

    await tester.pumpWidget(VipoApp(deps: deps));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TimerScreen), findsOneWidget);
  });
}