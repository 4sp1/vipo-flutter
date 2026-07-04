// ignore_for_file: type=lint
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:vipo/data/api/src/model/pomodoro_state.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_note_request.g.dart';


@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateNoteRequest {
  /// Returns a new [CreateNoteRequest] instance.
  CreateNoteRequest({

    required  this.note,

    required  this.pomodoroState,
  });

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





    @override
    bool operator ==(Object other) => identical(this, other) || other is CreateNoteRequest &&
      other.note == note &&
      other.pomodoroState == pomodoroState;

    @override
    int get hashCode =>
        note.hashCode +
        pomodoroState.hashCode;

  factory CreateNoteRequest.fromJson(Map<String, dynamic> json) => _$CreateNoteRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateNoteRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

