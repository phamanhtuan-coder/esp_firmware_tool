///
//  Generated code. Do not modify.
//  source: log_service.proto
//
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,unnecessary_const,non_constant_identifier_names,library_prefixes,unused_import,unused_shown_name,return_of_invalid_type,unnecessary_this,prefer_final_fields

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class LogRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'LogRequest',
      package: const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'esp_firmware',
      createEmptyInstance: create)
    ..aOB(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'enable')
    ..hasRequiredFields = false;

  LogRequest._() : super();
  factory LogRequest({
    $core.bool? enable,
  }) {
    final _result = create();
    if (enable != null) {
      _result.enable = enable;
    }
    return _result;
  }

  factory LogRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory LogRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  @$core.override
  LogRequest clone() => LogRequest()..mergeFromMessage(this);

  @$core.override
  LogRequest copyWith(void Function(LogRequest) updates) =>
      super.copyWith((message) => updates(message as LogRequest)) as LogRequest;

  @$core.override
  $core.Map<$core.String, $core.dynamic> toJson() => {'enable': enable};

  @$core.override
  LogRequest createEmptyInstance() => create();

  static LogRequest create() => LogRequest._();

  LogRequest createEmptyInstance() => create();

  static $pb.PbList<LogRequest> createRepeated() => $pb.PbList<LogRequest>();

  @$core.override
  set enable($core.bool v) { $_setBool(0, v); }

  @$core.override
  $core.bool get enable => $_getBF(0);

  @$core.override
  $core.bool hasEnable() => $_has(0);

  @$core.override
  void clearEnable() => clearField(1);
}

class LogResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'LogResponse',
      package: const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'esp_firmware',
      createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'message')
    ..aOS(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestamp')
    ..aOS(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'level')
    ..aOS(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'step')
    ..aOS(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'deviceId')
    ..hasRequiredFields = false;

  LogResponse._() : super();
  factory LogResponse({
    $core.String? message,
    $core.String? timestamp,
    $core.String? level,
    $core.String? step,
    $core.String? deviceId,
  }) {
    final _result = create();
    if (message != null) {
      _result.message = message;
    }
    if (timestamp != null) {
      _result.timestamp = timestamp;
    }
    if (level != null) {
      _result.level = level;
    }
    if (step != null) {
      _result.step = step;
    }
    if (deviceId != null) {
      _result.deviceId = deviceId;
    }
    return _result;
  }

  factory LogResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory LogResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  @$core.override
  LogResponse clone() => LogResponse()..mergeFromMessage(this);

  @$core.override
  LogResponse copyWith(void Function(LogResponse) updates) =>
      super.copyWith((message) => updates(message as LogResponse)) as LogResponse;

  @$core.override
  $core.Map<$core.String, $core.dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp,
      'level': level,
      'step': step,
      'deviceId': deviceId
    };
  }

  @$core.override
  LogResponse createEmptyInstance() => create();

  static LogResponse create() => LogResponse._();

  static $pb.PbList<LogResponse> createRepeated() => $pb.PbList<LogResponse>();

  @$core.override
  $core.String get message => $_getSZ(0);

  @$core.override
  set message($core.String v) { $_setString(0, v); }

  @$core.override
  $core.bool hasMessage() => $_has(0);

  @$core.override
  void clearMessage() => clearField(1);

  @$core.override
  $core.String get timestamp => $_getSZ(1);

  @$core.override
  set timestamp($core.String v) { $_setString(1, v); }

  @$core.override
  $core.bool hasTimestamp() => $_has(1);

  @$core.override
  void clearTimestamp() => clearField(2);

  @$core.override
  $core.String get level => $_getSZ(2);

  @$core.override
  set level($core.String v) { $_setString(2, v); }

  @$core.override
  $core.bool hasLevel() => $_has(2);

  @$core.override
  void clearLevel() => clearField(3);

  @$core.override
  $core.String get step => $_getSZ(3);

  @$core.override
  set step($core.String v) { $_setString(3, v); }

  @$core.override
  $core.bool hasStep() => $_has(3);

  @$core.override
  void clearStep() => clearField(4);

  @$core.override
  $core.String get deviceId => $_getSZ(4);

  @$core.override
  set deviceId($core.String v) { $_setString(4, v); }

  @$core.override
  $core.bool hasDeviceId() => $_has(4);

  @$core.override
  void clearDeviceId() => clearField(5);
}