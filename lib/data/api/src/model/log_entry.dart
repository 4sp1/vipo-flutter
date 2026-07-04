// ignore_for_file: type=lint
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:vipo/data/api/src/model/log_action.dart';
import 'package:vipo/data/api/src/model/pomodoro_state.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'log_entry.g.dart';


@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LogEntry {
  /// Returns a new [LogEntry] instance.
  LogEntry({

    required  this.id,

    required  this.action,

    required  this.session,

    required  this.timestamp,

     this.payload,
  });

  @JsonKey(
    
    name: r'id',
    required: true,
    includeIfNull: false,
  )


  final int id;



  @JsonKey(
    
    name: r'action',
    required: true,
    includeIfNull: false,
  )


  final LogAction action;



  @JsonKey(
    
    name: r'session',
    required: true,
    includeIfNull: false,
  )


  final PomodoroState session;



  @JsonKey(
    
    name: r'timestamp',
    required: true,
    includeIfNull: false,
  )


  final DateTime timestamp;



      /// Optional action-specific data
  @JsonKey(
    
    name: r'payload',
    required: false,
    includeIfNull: false,
  )


  final Object? payload;





    @override
    bool operator ==(Object other) => identical(this, other) || other is LogEntry &&
      other.id == id &&
      other.action == action &&
      other.session == session &&
      other.timestamp == timestamp &&
      other.payload == payload;

    @override
    int get hashCode =>
        id.hashCode +
        action.hashCode +
        session.hashCode +
        timestamp.hashCode +
        payload.hashCode;

  factory LogEntry.fromJson(Map<String, dynamic> json) => _$LogEntryFromJson(json);

  Map<String, dynamic> toJson() => _$LogEntryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

