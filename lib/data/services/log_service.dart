import 'dart:async';

import 'package:esp_firmware_tool/data/models/log_entry.dart';
import '../generated/log_service.pb.dart' as pb;
import '../generated/log_service.pbgrpc.dart' as grpc;
import 'package:grpc/grpc.dart';

// Note: Using explicit prefixes to avoid class name conflicts

class LogService {
  static const String _host = 'localhost';
  static const int _port = 50051;

  ClientChannel? _channel;
  grpc.LogServiceClient? _client;
  StreamSubscription<pb.LogResponse>? _logSubscription;
  final _logStreamController = StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get logStream => _logStreamController.stream;

  Future<void> initialize() async {
    _channel = ClientChannel(
      _host,
      port: _port,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );

    _client = grpc.LogServiceClient(_channel!);
    _startLogStream();
  }

  Future<void> _startLogStream() async {
    try {
      final request = pb.LogRequest()..enable = true;
      final response = _client!.streamLogs(request);

      _logSubscription = response.listen(
        (logResponse) {
          final logEntry = LogEntry(
            message: logResponse.message,
            timestamp: DateTime.parse(logResponse.timestamp),
            level: _parseLogLevel(logResponse.level),
            step: _parseProcessStep(logResponse.step),
            deviceId: logResponse.deviceId,
          );

          _logStreamController.add(logEntry);
        },
        onError: (e) {
          print('Error receiving logs: $e');
          Future.delayed(const Duration(seconds: 5), _startLogStream);
        },
        onDone: () {
          print('Log stream ended, trying to reconnect...');
          Future.delayed(const Duration(seconds: 5), _startLogStream);
        },
      );
    } catch (e) {
      print('Failed to connect to log service: $e');
      Future.delayed(const Duration(seconds: 5), _startLogStream);
    }
  }

  LogLevel _parseLogLevel(String level) {
    switch (level.toLowerCase()) {
      case 'info': return LogLevel.info;
      case 'warning': return LogLevel.warning;
      case 'error': return LogLevel.error;
      case 'success': return LogLevel.success;
      default: return LogLevel.info;
    }
  }

  ProcessStep _parseProcessStep(String step) {
    switch (step.toLowerCase()) {
      case 'usbcheck': return ProcessStep.usbCheck;
      case 'compile': return ProcessStep.compile;
      case 'flash': return ProcessStep.flash;
      case 'error': return ProcessStep.error;
      default: return ProcessStep.other;
    }
  }

  Future<void> dispose() async {
    await _logSubscription?.cancel();
    await _logStreamController.close();
    await _channel?.shutdown();
  }
}