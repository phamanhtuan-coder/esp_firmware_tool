enum LogLevel {
  info,
  warning,
  error,
  success,
  verbose,
  debug,
  input, // User input in serial monitor
  system, // System notifications
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
  final Function(String) onSerialInput;

  SerialInputLogEntry({
    required String prompt,
    required this.onSerialInput,
    required super.step,
    required super.deviceId,
  }) : super(
          message: prompt,
          timestamp: DateTime.now(),
          level: LogLevel.input,
          requiresInput: true,
          origin: 'serial-monitor',
        );
}

// Special log entry for device selection from batch
class BatchDeviceSelectionLogEntry extends LogEntry {
  final List<String> availableSerials;
  final String selectedSerial;
  final Function(String) onSerialSelect;

  BatchDeviceSelectionLogEntry({
    required this.availableSerials,
    required this.onSerialSelect,
    this.selectedSerial = '',
    required String prompt,
    required super.step,
    super.deviceId,
  }) : super(
          message: prompt,
          timestamp: DateTime.now(),
          level: LogLevel.system,
          requiresInput: true,
          origin: 'system',
        );
}

// Special log entry for firmware template selection
class FirmwareSelectionLogEntry extends LogEntry {
  final List<FirmwareTemplate> availableTemplates;
  final Function(String) onTemplateSelect;
  final String selectedTemplateId;

  FirmwareSelectionLogEntry({
    required this.availableTemplates,
    required this.onTemplateSelect,
    this.selectedTemplateId = '',
    required String prompt,
    required super.step,
    super.deviceId,
  }) : super(
          message: prompt,
          timestamp: DateTime.now(),
          level: LogLevel.system,
          requiresInput: true,
          origin: 'system',
        );
}

// Class to represent a firmware template
class FirmwareTemplate {
  final String id;
  final String name;
  final String version;
  final String deviceType;
  final String description;
  final String? localPath; // Path if downloaded locally

  FirmwareTemplate({
    required this.id,
    required this.name,
    required this.version,
    required this.deviceType,
    required this.description,
    this.localPath,
  });

  factory FirmwareTemplate.fromJson(Map<String, dynamic> json) {
    return FirmwareTemplate(
      id: json['id'],
      name: json['name'],
      version: json['version'],
      deviceType: json['deviceType'],
      description: json['description'] ?? '',
      localPath: json['localPath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'deviceType': deviceType,
      'description': description,
      'localPath': localPath,
    };
  }
}