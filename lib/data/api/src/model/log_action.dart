// ignore_for_file: type=lint
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// Timer event action. 'new_note' is excluded — use POST /notes instead.
enum LogAction {
          /// Timer event action. 'new_note' is excluded — use POST /notes instead.
      @JsonValue(r'start')
      start(r'start'),
          /// Timer event action. 'new_note' is excluded — use POST /notes instead.
      @JsonValue(r'pause')
      pause(r'pause'),
          /// Timer event action. 'new_note' is excluded — use POST /notes instead.
      @JsonValue(r'reset')
      reset(r'reset'),
          /// Timer event action. 'new_note' is excluded — use POST /notes instead.
      @JsonValue(r'expire')
      expire(r'expire'),
          /// Timer event action. 'new_note' is excluded — use POST /notes instead.
      @JsonValue(r'resume')
      resume(r'resume'),
          /// Timer event action. 'new_note' is excluded — use POST /notes instead.
      @JsonValue(r'select')
      select(r'select');

  const LogAction(this.value);

  final String value;

  @override
  String toString() => value;
}
