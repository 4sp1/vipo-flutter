import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/notes/notes_event.dart';
import 'package:vipo/blocs/notes/notes_state.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';

/// Pure view for the notes list.
///
/// Owns no state. Reads notes state from the ambient [NotesBloc] (provided in
/// `main.dart` via [AppDeps]) and dispatches user interactions back to it via
/// [BlocBuilder]. The initial fetch is self-dispatched by [NotesBloc]'s
/// constructor — no view priming is needed.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  void _showAddNoteDialog(BuildContext context) {
    final timerMode = context.read<TimerBloc>().state.mode;
    final notesBloc = context.read<NotesBloc>();
    final controller = TextEditingController();

    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('New Note'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Enter note content',
            autofocus: true,
            maxLines: 3,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final content = controller.text.trim();
              if (content.isNotEmpty) {
                notesBloc.add(
                  NoteCreated(
                    content: content,
                    pomodoroState: timerMode,
                  ),
                );
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Notes'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showAddNoteDialog(context),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BlocBuilder<NotesBloc, NotesState>(
          builder: (context, state) {
            return switch (state) {
              NotesInitial() || NotesLoadInProgress() =>
                const Center(child: CupertinoActivityIndicator()),
              NotesLoadSuccess(:final notes) => notes.isEmpty
                  ? const Center(child: Text('No notes yet'))
                  : ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return Dismissible(
                          key: ValueKey(note.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            color: CupertinoColors.systemRed,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(
                              CupertinoIcons.delete,
                              color: CupertinoColors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            context
                                .read<NotesBloc>()
                                .add(NoteDeleted(note.id));
                            return true;
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(note.content),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(note.createdAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              NotesLoadFailure(:final message) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(message),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        onPressed: () => context
                            .read<NotesBloc>()
                            .add(NotesFetchRequested()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              _ => const Center(child: CupertinoActivityIndicator()),
            };
          },
        ),
      ),
    );
  }
}