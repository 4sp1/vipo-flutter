// ignore_for_file: type=lint
import 'package:vipo/data/api/src/model/create_log_entry_request.dart';
import 'package:vipo/data/api/src/model/create_note_request.dart';
import 'package:vipo/data/api/src/model/error.dart';
import 'package:vipo/data/api/src/model/log_entry.dart';
import 'package:vipo/data/api/src/model/log_entry_list.dart';
import 'package:vipo/data/api/src/model/note.dart';
import 'package:vipo/data/api/src/model/note_list.dart';

final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

  ReturnType deserialize<ReturnType, BaseType>(dynamic value, String targetType, {bool growable= true}) {
      switch (targetType) {
        case 'String':
          return '$value' as ReturnType;
        case 'int':
          return (value is int ? value : int.parse('$value')) as ReturnType;
        case 'bool':
          if (value is bool) {
            return value as ReturnType;
          }
          final valueString = '$value'.toLowerCase();
          return (valueString == 'true' || valueString == '1') as ReturnType;
        case 'double':
          return (value is double ? value : double.parse('$value')) as ReturnType;
        case 'CreateLogEntryRequest':
          return CreateLogEntryRequest.fromJson(value as Map<String, dynamic>) as ReturnType;
        case 'CreateNoteRequest':
          return CreateNoteRequest.fromJson(value as Map<String, dynamic>) as ReturnType;
        case 'Error':
          return Error.fromJson(value as Map<String, dynamic>) as ReturnType;
        case 'LogAction':
          
          
        case 'LogEntry':
          return LogEntry.fromJson(value as Map<String, dynamic>) as ReturnType;
        case 'LogEntryList':
          return LogEntryList.fromJson(value as Map<String, dynamic>) as ReturnType;
        case 'Note':
          return Note.fromJson(value as Map<String, dynamic>) as ReturnType;
        case 'NoteList':
          return NoteList.fromJson(value as Map<String, dynamic>) as ReturnType;
        case 'PomodoroState':
          
          
        default:
          RegExpMatch? match;

          if (value is List && (match = _regList.firstMatch(targetType)) != null) {
            targetType = match![1]!; // ignore: parameter_assignments
            return value
              .map<BaseType>((dynamic v) => deserialize<BaseType, BaseType>(v, targetType, growable: growable))
              .toList(growable: growable) as ReturnType;
          }
          if (value is Set && (match = _regSet.firstMatch(targetType)) != null) {
            targetType = match![1]!; // ignore: parameter_assignments
            return value
              .map<BaseType>((dynamic v) => deserialize<BaseType, BaseType>(v, targetType, growable: growable))
              .toSet() as ReturnType;
          }
          if (value is Map && (match = _regMap.firstMatch(targetType)) != null) {
            targetType = match![1]!.trim(); // ignore: parameter_assignments
            return Map<String, BaseType>.fromIterables(
              value.keys as Iterable<String>,
              value.values.map((dynamic v) => deserialize<BaseType, BaseType>(v, targetType, growable: growable)),
            ) as ReturnType;
          }
          break;
    }
    throw Exception('Cannot deserialize');
  }