// ignore_for_file: type=lint
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:vipo/data/api/src/model/note.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'note_list.g.dart';


@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NoteList {
  /// Returns a new [NoteList] instance.
  NoteList({

     this.notes,

     this.total,
  });

  @JsonKey(
    
    name: r'notes',
    required: false,
    includeIfNull: false,
  )


  final List<Note>? notes;



  @JsonKey(
    
    name: r'total',
    required: false,
    includeIfNull: false,
  )


  final int? total;





    @override
    bool operator ==(Object other) => identical(this, other) || other is NoteList &&
      other.notes == notes &&
      other.total == total;

    @override
    int get hashCode =>
        notes.hashCode +
        total.hashCode;

  factory NoteList.fromJson(Map<String, dynamic> json) => _$NoteListFromJson(json);

  Map<String, dynamic> toJson() => _$NoteListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

