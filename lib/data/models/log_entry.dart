import 'package:flutter/foundation.dart';

enum LogLevel {
  info,
  warning,
  error,
  success,
}

enum ProcessStep {
  usbCheck,
  compile,
  flash,
  error,
  other,
}

class LogEntry {
  final String message;
  final DateTime timestamp;
  final LogLevel level;
  final ProcessStep step;
  final String deviceId;

  LogEntry({
    required this.message,
    required this.timestamp,
    required this.level,
    required this.step,
    required this.deviceId,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      level: LogLevel.values.firstWhere(
        (e) => e.toString() == 'LogLevel.${json['level']}',
        orElse: () => LogLevel.info,
      ),
      step: ProcessStep.values.firstWhere(
        (e) => e.toString() == 'ProcessStep.${json['step']}',
        orElse: () => ProcessStep.other,
      ),
      deviceId: json['deviceId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'level': level.toString().split('.').last,
      'step': step.toString().split('.').last,
      'deviceId': deviceId,
    };
  }
}