// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NoteList _$NoteListFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NoteList', json, ($checkedConvert) {
      final val = NoteList(
        notes: $checkedConvert(
          'notes',
          (v) => (v as List<dynamic>?)
              ?.map((e) => Note.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        total: $checkedConvert('total', (v) => (v as num?)?.toInt()),
      );
      return val;
    });

Map<String, dynamic> _$NoteListToJson(NoteList instance) => <String, dynamic>{
  'notes': ?instance.notes?.map((e) => e.toJson()).toList(),
  'total': ?instance.total,
};
