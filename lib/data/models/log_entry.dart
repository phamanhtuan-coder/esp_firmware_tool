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
  deviceRefresh,       // New step for refreshing device list from server
  systemStart,         // System startup and initialization
  systemEvent,         // System events like device connection/disconnection
  batchSelection,      // Selecting a batch of devices
}

enum DataDisplayMode {
  ascii,
  hex,
  mixed,
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
  final DataDisplayMode displayMode;

  LogEntry({
    required this.message,
    required this.timestamp,
    required this.level,
    required this.step,
    this.deviceId = '',
    this.requiresInput = false,
    this.origin,
    this.rawOutput,
    this.displayMode = DataDisplayMode.ascii,
  });

  // Format the timestamp in a readable form
  String get formattedTimestamp =>
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';

  // Convert message to hex view if needed
  String getFormattedMessage(DataDisplayMode mode) {
    if (mode == DataDisplayMode.ascii || rawOutput == null) {
      return message;
    } else if (mode == DataDisplayMode.hex) {
      return _convertToHex(rawOutput!);
    } else {
      // Mixed mode - show both ascii and hex
      return '$message\n${_convertToHex(rawOutput!)}';
    }
  }

  // Convert a string to hex representation
  String _convertToHex(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final charCode = input.codeUnitAt(i);
      buffer.write(charCode.toRadixString(16).padLeft(2, '0'));
      buffer.write(' ');
      // Add line break every 16 bytes for readability
      if ((i + 1) % 16 == 0) buffer.write('\n');
    }
    return buffer.toString();
  }

  // Create a copy with a different display mode
  LogEntry withDisplayMode(DataDisplayMode newMode) {
    return LogEntry(
      message: message,
      timestamp: timestamp,
      level: level,
      step: step,
      deviceId: deviceId,
      requiresInput: requiresInput,
      origin: origin,
      rawOutput: rawOutput,
      displayMode: newMode,
    );
  }

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
      displayMode: DataDisplayMode.ascii,
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

