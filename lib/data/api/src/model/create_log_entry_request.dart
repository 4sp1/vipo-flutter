// ignore_for_file: type=lint
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:vipo/data/api/src/model/log_action.dart';
import 'package:vipo/data/api/src/model/pomodoro_state.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_log_entry_request.g.dart';


@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateLogEntryRequest {
  /// Returns a new [CreateLogEntryRequest] instance.
  CreateLogEntryRequest({

    required  this.action,

    required  this.session,

     this.payload,
  });

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



      /// Optional action-specific data
  @JsonKey(
    
    name: r'payload',
    required: false,
    includeIfNull: false,
  )


  final Object? payload;





    @override
    bool operator ==(Object other) => identical(this, other) || other is CreateLogEntryRequest &&
      other.action == action &&
      other.session == session &&
      other.payload == payload;

    @override
    int get hashCode =>
        action.hashCode +
        session.hashCode +
        payload.hashCode;

  factory CreateLogEntryRequest.fromJson(Map<String, dynamic> json) => _$CreateLogEntryRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateLogEntryRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

