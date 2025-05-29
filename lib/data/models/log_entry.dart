enum LogLevel {
  info,
  warning,
  error,
  success,
  verbose,
  debug,
  input, // User input in serial monitor
  system, // System notifications
  serialOutput, // Output from serial monitor
  consoleOutput, // Output from console log
}

enum ProcessStep {
  usbCheck,
  compile,
  flash,
  error,
  other,
  installCore,
  installLibrary,
  serialMonitor,
  consoleLog, // New step for console logging
  scanQrCode,
  selectFirmware,
  selectDeviceType,
  productBatch,
  updateStatus,
  deviceSelection,     // New step for device selection from batch
  firmwareDownload,    // New step for firmware template download
  templatePreparation, // New step for preparing templates with serial numbers
  systemEvent,         // New step for system events like USB connect/disconnect
}

class LogEntry {
  final String message;
  final DateTime timestamp;
  final LogLevel level;
  final ProcessStep step;
  final String deviceId;
  final bool requiresInput;
  final String? origin; // 'arduino-cli', 'system', 'user-input', 'serial-monitor'
  final String? rawOutput; // Store raw output from Arduino CLI for parsing/display

  LogEntry({
    required this.message,
    required this.timestamp,
    required this.level,
    required this.step,
    this.deviceId = '',
    this.requiresInput = false,
    this.origin,
    this.rawOutput,
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
      deviceId: json['deviceId'] ?? '',
      requiresInput: json['requiresInput'] ?? false,
      origin: json['origin'],
      rawOutput: json['rawOutput'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'level': level.toString().split('.').last,
      'step': step.toString().split('.').last,
      'deviceId': deviceId,
      'requiresInput': requiresInput,
      'origin': origin,
      'rawOutput': rawOutput,
    };
  }
}

// Special log entry for system events requiring user input
class InputRequestLogEntry extends LogEntry {
  final String prompt;
  final Function(String) onInput;

  InputRequestLogEntry({
    required this.prompt,
    required this.onInput,
    required super.step,
    super.deviceId,
  }) : super(
          message: prompt,
          timestamp: DateTime.now(),
          level: LogLevel.info,
          requiresInput: true,
          origin: 'system',
        );
}

// Special log entry for serial monitor input
class SerialInputLogEntry extends LogEntry {
  final String prompt;
  final Function(String) onSerialInput;

  SerialInputLogEntry({
    required this.prompt,
    required this.onSerialInput,
    required super.step,
    super.deviceId,
  }) : super(
          message: prompt,
          timestamp: DateTime.now(),
          level: LogLevel.info,
          requiresInput: true,
          origin: 'serial-monitor',
        );
}