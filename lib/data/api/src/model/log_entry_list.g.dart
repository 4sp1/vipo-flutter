// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_entry_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LogEntryList _$LogEntryListFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LogEntryList', json, ($checkedConvert) {
      final val = LogEntryList(
        entries: $checkedConvert(
          'entries',
          (v) => (v as List<dynamic>?)
              ?.map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        total: $checkedConvert('total', (v) => (v as num?)?.toInt()),
      );
      return val;
    });

Map<String, dynamic> _$LogEntryListToJson(LogEntryList instance) =>
    <String, dynamic>{
      'entries': ?instance.entries?.map((e) => e.toJson()).toList(),
      'total': ?instance.total,
    };
