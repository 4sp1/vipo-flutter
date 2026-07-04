// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_log_entry_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateLogEntryRequest _$CreateLogEntryRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateLogEntryRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['action', 'session']);
  final val = CreateLogEntryRequest(
    action: $checkedConvert(
      'action',
      (v) => $enumDecode(_$LogActionEnumMap, v),
    ),
    session: $checkedConvert(
      'session',
      (v) => $enumDecode(_$PomodoroStateEnumMap, v),
    ),
    payload: $checkedConvert('payload', (v) => v),
  );
  return val;
});

Map<String, dynamic> _$CreateLogEntryRequestToJson(
  CreateLogEntryRequest instance,
) => <String, dynamic>{
  'action': _$LogActionEnumMap[instance.action]!,
  'session': _$PomodoroStateEnumMap[instance.session]!,
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
