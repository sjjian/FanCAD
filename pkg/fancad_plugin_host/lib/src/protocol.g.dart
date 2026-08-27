// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'protocol.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$RpcRequestToJson(RpcRequest instance) =>
    <String, dynamic>{
      'method': instance.method,
      if (_omitEmptyParams(instance.params) case final value?) 'params': value,
      if (instance.id case final value?) 'id': value,
    };

RpcError _$RpcErrorFromJson(Map<String, dynamic> json) => RpcError(
  (json['code'] as num).toInt(),
  json['message'] as String,
  data: json['data'],
);

Map<String, dynamic> _$RpcErrorToJson(RpcError instance) => <String, dynamic>{
  'code': instance.code,
  'message': instance.message,
  if (instance.data case final value?) 'data': value,
};
