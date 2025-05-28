//  Generated code. Do not modify.
//  source: log_service.proto
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,unnecessary_const,non_constant_identifier_names,library_prefixes,unused_import,unused_shown_name,return_of_invalid_type,unnecessary_this,prefer_final_fields

import 'dart:async' as $async;

import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'log_service.pb.dart' as $0;

export 'log_service.pb.dart';

class LogServiceClient extends $grpc.Client {
  static final _$streamLogs = $grpc.ClientMethod<$0.LogRequest, $0.LogResponse>(
      '/esp_firmware.LogService/StreamLogs',
      ($0.LogRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.LogResponse.fromBuffer(value));

  LogServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options, interceptors: interceptors);

  $grpc.ResponseStream<$0.LogResponse> streamLogs($0.LogRequest request,
      {$grpc.CallOptions? options}) {
    return $createStreamingCall(
        _$streamLogs, $async.Stream.fromIterable([request]),
        options: options);
  }
}

abstract class LogServiceBase extends $grpc.Service {
  $core.String get $name => 'esp_firmware.LogService';

  LogServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.LogRequest, $0.LogResponse>(
        'StreamLogs',
        streamLogs_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.LogRequest.fromBuffer(value),
        ($0.LogResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.LogResponse> streamLogs_Pre(
      $grpc.ServiceCall call, $async.Future<$0.LogRequest> request) async* {
    yield* streamLogs(call, await request);
  }

  $async.Stream<$0.LogResponse> streamLogs(
      $grpc.ServiceCall call, $0.LogRequest request);
}