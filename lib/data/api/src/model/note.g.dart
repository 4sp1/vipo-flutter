// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Note _$NoteFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Note',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['id', 'note', 'pomodoro_state', 'created_at'],
    );
    final val = Note(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      note: $checkedConvert('note', (v) => v as String),
      pomodoroState: $checkedConvert(
        'pomodoro_state',
        (v) => $enumDecode(_$PomodoroStateEnumMap, v),
      ),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'pomodoroState': 'pomodoro_state',
    'createdAt': 'created_at',
  },
);

Map<String, dynamic> _$NoteToJson(Note instance) => <String, dynamic>{
  'id': instance.id,
  'note': instance.note,
  'pomodoro_state': _$PomodoroStateEnumMap[instance.pomodoroState]!,
  'created_at': instance.createdAt.toIso8601String(),
};

const _$PomodoroStateEnumMap = {
  PomodoroState.work: 'work',
  PomodoroState.shortBreak: 'short_break',
  PomodoroState.longBreak: 'long_break',
};
