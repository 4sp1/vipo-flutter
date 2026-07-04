// ignore_for_file: type=lint
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:vipo/data/api/src/model/pomodoro_state.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'note.g.dart';


@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Note {
  /// Returns a new [Note] instance.
  Note({

    required  this.id,

    required  this.note,

    required  this.pomodoroState,

    required  this.createdAt,
  });

  @JsonKey(
    
    name: r'id',
    required: true,
    includeIfNull: false,
  )


  final int id;



  @JsonKey(
    
    name: r'note',
    required: true,
    includeIfNull: false,
  )


  final String note;



  @JsonKey(
    
    name: r'pomodoro_state',
    required: true,
    includeIfNull: false,
  )


  final PomodoroState pomodoroState;



  @JsonKey(
    
    name: r'created_at',
    required: true,
    includeIfNull: false,
  )


  final DateTime createdAt;





    @override
    bool operator ==(Object other) => identical(this, other) || other is Note &&
      other.id == id &&
      other.note == note &&
      other.pomodoroState == pomodoroState &&
      other.createdAt == createdAt;

    @override
    int get hashCode =>
        id.hashCode +
        note.hashCode +
        pomodoroState.hashCode +
        createdAt.hashCode;

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);

  Map<String, dynamic> toJson() => _$NoteToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

