// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Error _$ErrorFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Error', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['message']);
      final val = Error(
        message: $checkedConvert('message', (v) => v as String),
        code: $checkedConvert('code', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ErrorToJson(Error instance) => <String, dynamic>{
  'message': instance.message,
  'code': ?instance.code,
};
