//  Generated code. Do not modify.
//  source: log_service.proto
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,unnecessary_const,non_constant_identifier_names,library_prefixes,unused_import,unused_shown_name,return_of_invalid_type,unnecessary_this,prefer_final_fields

import 'dart:core' as $core;
import 'package:protobuf/protobuf.dart' as $pb;

class LogRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _info = $pb.BuilderInfo(
      'esp_firmware.LogRequest',
      createEmptyInstance: create)
    ..aOB(1, 'enable')
    ..hasRequiredFields = false;

  LogRequest._() : super();

  static LogRequest create() => LogRequest._();

  @$core.override
  LogRequest clone() => LogRequest()..mergeFromMessage(this);

  @$core.override
  LogRequest createEmptyInstance() => create();

  @$core.override
  $pb.BuilderInfo get info_ => _info;

  factory LogRequest({
    $core.bool? enable,
  }) {
    final result = create();
    if (enable != null) {
      result.enable = enable;
    }
    return result;
  }

  factory LogRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  factory LogRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  set enable($core.bool v) { $_setBool(0, v); }
  $core.bool get enable => $_getBF(0);
  $core.bool hasEnable() => $_has(0);
  void clearEnable() => clearField(1);
}

class LogResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _info = $pb.BuilderInfo(
      'esp_firmware.LogResponse',
      createEmptyInstance: create)
    ..aOS(1, 'message')
    ..aOS(2, 'timestamp')
    ..aOS(3, 'level')
    ..aOS(4, 'step')
    ..aOS(5, 'deviceId')
    ..hasRequiredFields = false;

  LogResponse._() : super();

  static LogResponse create() => LogResponse._();

  @$core.override
  LogResponse clone() => LogResponse()..mergeFromMessage(this);

  @$core.override
  LogResponse createEmptyInstance() => create();

  @$core.override
  $pb.BuilderInfo get info_ => _info;

  factory LogResponse({
    $core.String? message,
    $core.String? timestamp,
    $core.String? level,
    $core.String? step,
    $core.String? deviceId,
  }) {
    final result = create();
    if (message != null) {
      result.message = message;
    }
    if (timestamp != null) {
      result.timestamp = timestamp;
    }
    if (level != null) {
      result.level = level;
    }
    if (step != null) {
      result.step = step;
    }
    if (deviceId != null) {
      result.deviceId = deviceId;
    }
    return result;
  }

  factory LogResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  factory LogResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  $core.String get message => $_getSZ(0);
  set message($core.String v) { $_setString(0, v); }
  $core.bool hasMessage() => $_has(0);
  void clearMessage() => clearField(1);

  $core.String get timestamp => $_getSZ(1);
  set timestamp($core.String v) { $_setString(1, v); }
  $core.bool hasTimestamp() => $_has(1);
  void clearTimestamp() => clearField(2);

  $core.String get level => $_getSZ(2);
  set level($core.String v) { $_setString(2, v); }
  $core.bool hasLevel() => $_has(2);
  void clearLevel() => clearField(3);

  $core.String get step => $_getSZ(3);
  set step($core.String v) { $_setString(3, v); }
  $core.bool hasStep() => $_has(3);
  void clearStep() => clearField(4);

  $core.String get deviceId => $_getSZ(4);
  set deviceId($core.String v) { $_setString(4, v); }
  $core.bool hasDeviceId() => $_has(4);
  void clearDeviceId() => clearField(5);
}