// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_note_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateNoteRequest _$CreateNoteRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreateNoteRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['note', 'pomodoro_state']);
      final val = CreateNoteRequest(
        note: $checkedConvert('note', (v) => v as String),
        pomodoroState: $checkedConvert(
          'pomodoro_state',
          (v) => $enumDecode(_$PomodoroStateEnumMap, v),
        ),
      );
      return val;
    }, fieldKeyMap: const {'pomodoroState': 'pomodoro_state'});

Map<String, dynamic> _$CreateNoteRequestToJson(CreateNoteRequest instance) =>
    <String, dynamic>{
      'note': instance.note,
      'pomodoro_state': _$PomodoroStateEnumMap[instance.pomodoroState]!,
    };

const _$PomodoroStateEnumMap = {
  PomodoroState.work: 'work',
  PomodoroState.shortBreak: 'short_break',
  PomodoroState.longBreak: 'long_break',
};
