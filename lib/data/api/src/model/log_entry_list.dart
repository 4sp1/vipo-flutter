// ignore_for_file: type=lint
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:vipo/data/api/src/model/log_entry.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'log_entry_list.g.dart';


@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LogEntryList {
  /// Returns a new [LogEntryList] instance.
  LogEntryList({

     this.entries,

     this.total,
  });

  @JsonKey(
    
    name: r'entries',
    required: false,
    includeIfNull: false,
  )


  final List<LogEntry>? entries;



  @JsonKey(
    
    name: r'total',
    required: false,
    includeIfNull: false,
  )


  final int? total;





    @override
    bool operator ==(Object other) => identical(this, other) || other is LogEntryList &&
      other.entries == entries &&
      other.total == total;

    @override
    int get hashCode =>
        entries.hashCode +
        total.hashCode;

  factory LogEntryList.fromJson(Map<String, dynamic> json) => _$LogEntryListFromJson(json);

  Map<String, dynamic> toJson() => _$LogEntryListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

