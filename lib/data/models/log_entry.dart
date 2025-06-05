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
  // Các bước khởi động và hệ thống
  systemStart, // Khởi động ứng dụng
  systemEvent, // Các sự kiện hệ thống (USB connect/disconnect...)
  // Các bước quản lý sản phẩm
  productBatch, // Quản lý lô sản phẩm
  batchSelection, // Chọn lô sản xuất
  deviceSelection, // Chọn thiết bị trong lô
  deviceStatus, // Trạng thái thiết bị (defective, ready...)
  deviceRefresh, // Refresh danh sách thiết bị từ server
  // Các bước quản lý firmware
  firmwareDownload, // Tải firmware từ server
  selectFirmware, // Chọn phiên bản firmware
  templatePreparation, // Chu��n bị template với serial number
  // Các bước nạp firmware
  firmwareCompile, // Biên dịch firmware
  firmwareUpload, // Nạp firmware vào thiết bị
  usbCheck, // Kiểm tra kết nối USB
  flash, // Quá trình flash
  // Các bước theo dõi và tương tác
  scanQrCode, // Quét mã QR
  serialMonitor, // Theo dõi cổng serial
  consoleLog, // Log console
  // Các bước quản lý thư viện
  installCore, // Cài đặt core
  installLibrary, // Cài đặt thư viện
  // Khác
  error, // Xử lý lỗi
  other, // Các bước khác
}

enum DataDisplayMode { ascii, hex, mixed }

class LogEntry {
  final String message;
  final DateTime timestamp;
  final LogLevel level;
  final ProcessStep step;
  final String deviceId;
  final bool requiresInput;
  final String?
  origin; // 'arduino-cli', 'system', 'user-input', 'serial-monitor'
  final String?
  rawOutput; // Store raw output from Arduino CLI for parsing/display
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
