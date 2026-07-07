/// Domain representation of a user note.
///
/// Field mapping vs the generated `lib/data/api/.../note.dart`:
///   id        (String)   <-  id             (int)
///   content   (String)   <-  note           (String)
///   createdAt (DateTime) <-  createdAt      (DateTime)
///   _         <-             pomodoroState  (PomodoroState)  // dropped
class Note {
  const Note({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String content;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          other.id == id &&
          other.content == content &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, content, createdAt);

  @override
  String toString() => 'Note(id: $id, content: $content, createdAt: $createdAt)';
}