// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LogEntry _$LogEntryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LogEntry', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['id', 'action', 'session', 'timestamp'],
      );
      final val = LogEntry(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        action: $checkedConvert(
          'action',
          (v) => $enumDecode(_$LogActionEnumMap, v),
        ),
        session: $checkedConvert(
          'session',
          (v) => $enumDecode(_$PomodoroStateEnumMap, v),
        ),
        timestamp: $checkedConvert(
          'timestamp',
          (v) => DateTime.parse(v as String),
        ),
        payload: $checkedConvert('payload', (v) => v),
      );
      return val;
    });

Map<String, dynamic> _$LogEntryToJson(LogEntry instance) => <String, dynamic>{
  'id': instance.id,
  'action': _$LogActionEnumMap[instance.action]!,
  'session': _$PomodoroStateEnumMap[instance.session]!,
  'timestamp': instance.timestamp.toIso8601String(),
  'payload': ?instance.payload,
};

const _$LogActionEnumMap = {
  LogAction.start: 'start',
  LogAction.pause: 'pause',
  LogAction.reset: 'reset',
  LogAction.expire: 'expire',
  LogAction.resume: 'resume',
  LogAction.select: 'select',
};

const _$PomodoroStateEnumMap = {
  PomodoroState.work: 'work',
  PomodoroState.shortBreak: 'short_break',
  PomodoroState.longBreak: 'long_break',
};
