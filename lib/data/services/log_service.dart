import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class LogService {
  // Stream controller for broadcasting logs to UI
  final _logStreamController = StreamController<LogEntry>.broadcast();

  // Current active process (compile, upload, etc.)
  Process? _activeProcess;

  // Serial monitor process
  Process? _serialMonitorProcess;

  // Device currently being monitored
  String? _currentDeviceId;

  // Whether the serial monitor is active
  bool _serialMonitorActive = false;

  // Base directory for firmware templates
  String? _firmwareTemplatesDir;

  // Map to track USB connected devices
  final Map<String, bool> _connectedDevices = {};

  // Current batch of devices being processed
  List<String> _currentBatchSerials = [];
  String _currentBatchId = '';

  // Public stream for UI to listen to
  Stream<LogEntry> get logStream => _logStreamController.stream;

  // Getter for current batch ID
  String get currentBatchId => _currentBatchId;

  // Constructor to initialize the service
  LogService() {
    _initFirmwareTemplatesDir();
  }

  // Initialize the service
  Future<void> initialize() async {
    await _initFirmwareTemplatesDir();

    // Add initial system log
    addLog(
      message: 'Log service initialized',
      level: LogLevel.info,
      step: ProcessStep.systemEvent,
      origin: 'system',
    );
  }

  // Initialize the firmware templates directory
  Future<void> _initFirmwareTemplatesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    _firmwareTemplatesDir = path.join(appDir.path, 'firmware_templates');

    // Create directory if it doesn't exist
    final dir = Directory(_firmwareTemplatesDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  // Method to add a log entry from any source
  void addLog({
    required String message,
    required LogLevel level,
    required ProcessStep step,
    String deviceId = '',
    bool requiresInput = false,
    String? origin,
    String? rawOutput,
  }) {
    final entry = LogEntry(
      message: message,
      timestamp: DateTime.now(),
      level: level,
      step: step,
      deviceId: deviceId,
      requiresInput: requiresInput,
      origin: origin,
      rawOutput: rawOutput,
    );

    _logStreamController.add(entry);
  }

  // Handle process output and convert to log entries with improved Arduino CLI output parsing
  void _processOutput(String output, ProcessStep step, String deviceId, {String? origin}) {
    // Check for common Arduino CLI error patterns with more specific detection
    if (output.contains('error:') || output.contains('Error:') || output.contains('ERROR:') ||
        output.contains('failed') || output.contains('Failed') || output.contains('FAILED')) {
      addLog(
        message: output.trim(),
        level: LogLevel.error,
        step: step,
        deviceId: deviceId,
        origin: origin ?? 'arduino-cli',
        rawOutput: output,
      );
    }
    // Warning patterns
    else if (output.contains('warning:') || output.contains('Warning:') || output.contains('WARNING:')) {
      addLog(
        message: output.trim(),
        level: LogLevel.warning,
        step: step,
        deviceId: deviceId,
        origin: origin ?? 'arduino-cli',
        rawOutput: output,
      );
    }
    // Success patterns with more specific detection
    else if (output.contains('Success') || output.contains('success') ||
             output.contains('Done') || output.contains('done') ||
             output.contains('Uploaded') || output.contains('uploaded') ||
             output.contains('Installed') || output.contains('installed') ||
             output.contains('Compiled') || output.contains('compiled') ||
             output.contains('Sketch uses') && output.contains('bytes')) {
      addLog(
        message: output.trim(),
        level: LogLevel.success,
        step: step,
        deviceId: deviceId,
        origin: origin ?? 'arduino-cli',
        rawOutput: output,
      );
    }
    // Progress/verbose information
    else if (output.contains('Compiling') || output.contains('compiling') ||
             output.contains('Uploading') || output.contains('uploading') ||
             output.contains('Verifying') || output.contains('verifying') ||
             output.contains('Installing') || output.contains('installing')) {
      addLog(
        message: output.trim(),
        level: LogLevel.verbose,
        step: step,
        deviceId: deviceId,
        origin: origin ?? 'arduino-cli',
        rawOutput: output,
      );
    }
    // Default case - info log
    else {
      addLog(
        message: output.trim(),
        level: LogLevel.info,
        step: step,
        deviceId: deviceId,
        origin: origin ?? 'arduino-cli',
        rawOutput: output,
      );
    }
  }

  // Run a process and stream its output as logs with improved error handling
  Future<int> runProcess(
    String executable,
    List<String> arguments, {
    required ProcessStep step,
    String workingDirectory = '',
    String deviceId = '',
    Map<String, String>? environment,
    bool showCommandInLogs = true,
  }) async {
    try {
      // Kill any existing process
      await killActiveProcess();

      // Start the new process
      _activeProcess = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory.isNotEmpty ? workingDirectory : null,
        environment: environment,
      );

      // Add log entry showing the command being executed if requested
      if (showCommandInLogs) {
        final commandString = '$executable ${arguments.join(' ')}';
        addLog(
          message: 'Running: $commandString',
          level: LogLevel.info,
          step: step,
          deviceId: deviceId,
          origin: 'system',
        );
      }

      // Stream stdout with improved line handling
      _activeProcess!.stdout
        .transform(utf8.decoder)
        .listen((data) {
          // Process line by line or handle as chunk if needed
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              _processOutput(line.trim(), step, deviceId);
            }
          }
        });

      // Stream stderr
      _activeProcess!.stderr
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              _processOutput(line.trim(), step, deviceId);
            }
          }
        });

      // Wait for process to complete
      final exitCode = await _activeProcess!.exitCode;

      if (exitCode == 0) {
        addLog(
          message: 'Process completed successfully',
          level: LogLevel.success,
          step: step,
          deviceId: deviceId,
          origin: 'system',
        );
      } else {
        addLog(
          message: 'Process failed with exit code: $exitCode',
          level: LogLevel.error,
          step: step,
          deviceId: deviceId,
          origin: 'system',
        );
      }

      _activeProcess = null;
      return exitCode;
    } catch (e) {
      addLog(
        message: 'Failed to start process: $e',
        level: LogLevel.error,
        step: step,
        deviceId: deviceId,
        origin: 'system',
      );
      return -1;
    }
  }

  // Enhanced serial monitor with better input handling
  Future<bool> startSerialMonitor(String port, int baudRate, String deviceId) async {
    // Close any existing serial monitor
    await stopSerialMonitor();

    try {
      // Start Arduino CLI serial monitor
      _serialMonitorProcess = await Process.start(
        'arduino-cli',
        ['monitor', '-p', port, '-c', 'baudrate=$baudRate'],
      );

      _currentDeviceId = deviceId;
      _serialMonitorActive = true;

      addLog(
        message: 'Serial monitor started on port $port at $baudRate baud',
        level: LogLevel.info,
        step: ProcessStep.serialMonitor,
        deviceId: deviceId,
        origin: 'system',
      );

      // Add a log entry for requesting input with Arduino IDE-like experience
      final inputRequestEntry = SerialInputLogEntry(
        prompt: 'Type commands to send to the device (Enter to send)',
        onSerialInput: sendToSerialMonitor,
        step: ProcessStep.serialMonitor,
        deviceId: deviceId,
      );

      _logStreamController.add(inputRequestEntry);

      // Stream stdout from serial monitor with improved buffering
      _serialMonitorProcess!.stdout
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              _processOutput(
                line.trim(),
                ProcessStep.serialMonitor,
                deviceId,
                origin: 'serial-monitor'
              );
            }
          }
        });

      // Stream stderr from serial monitor
      _serialMonitorProcess!.stderr
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              _processOutput(
                line.trim(),
                ProcessStep.serialMonitor,
                deviceId,
                origin: 'serial-monitor'
              );
            }
          }
        });

      // Monitor the process exit
      _serialMonitorProcess!.exitCode.then((exitCode) {
        _serialMonitorActive = false;
        _serialMonitorProcess = null;
        _currentDeviceId = null;

        addLog(
          message: 'Serial monitor closed',
          level: LogLevel.info,
          step: ProcessStep.serialMonitor,
          deviceId: deviceId,
          origin: 'system',
        );
      });

      return true;
    } catch (e) {
      addLog(
        message: 'Failed to start serial monitor: $e',
        level: LogLevel.error,
        step: ProcessStep.serialMonitor,
        deviceId: deviceId,
        origin: 'system',
      );
      return false;
    }
  }

  // Send data to the serial monitor with improved input handling
  void sendToSerialMonitor(String data) {
    if (_serialMonitorProcess != null && _serialMonitorActive) {
      try {
        // Send the input to the process
        _serialMonitorProcess!.stdin.writeln(data);

        // Log the input (with input level to display differently)
        addLog(
          message: '> $data',
          level: LogLevel.input,
          step: ProcessStep.serialMonitor,
          deviceId: _currentDeviceId ?? '',
          origin: 'user-input',
        );
      } catch (e) {
        addLog(
          message: 'Failed to send data to serial monitor: $e',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          deviceId: _currentDeviceId ?? '',
          origin: 'system',
        );
      }
    } else {
      addLog(
        message: 'No active serial monitor to send data to',
        level: LogLevel.warning,
        step: ProcessStep.serialMonitor,
        deviceId: _currentDeviceId ?? '',
        origin: 'system',
      );
    }
  }

  // Stop the serial monitor with improved cleanup
  Future<void> stopSerialMonitor() async {
    if (_serialMonitorProcess != null) {
      _serialMonitorActive = false;

      // Send a final log if we know the device ID
      if (_currentDeviceId != null) {
        addLog(
          message: 'Closing serial monitor...',
          level: LogLevel.info,
          step: ProcessStep.serialMonitor,
          deviceId: _currentDeviceId!,
          origin: 'system',
        );
      }

      // Kill the process
      try {
        _serialMonitorProcess!.kill();
      } catch (e) {
        print('Error killing serial monitor: $e');
      }

      _serialMonitorProcess = null;
      _currentDeviceId = null;
    }
  }

  // Clear logs for the specified device or all logs if deviceId is empty
  void clearLogs([String deviceId = '']) {
    // We can't clear the StreamController directly,
    // but we can send a special log entry that the UI can use to clear logs
    addLog(
      message: 'CLEAR_LOGS',
      level: LogLevel.info,
      step: ProcessStep.other,
      deviceId: deviceId,
      origin: 'system',
    );
  }

  // Register a USB device connection
  void registerUsbConnection(String deviceId, String port) {
    _connectedDevices[deviceId] = true;

    addLog(
      message: 'USB device connected: $deviceId on port $port',
      level: LogLevel.info,
      step: ProcessStep.systemEvent,
      deviceId: deviceId,
      origin: 'system',
    );
  }

  // Register a USB device disconnection and clear its logs
  void registerUsbDisconnection(String deviceId) {
    _connectedDevices.remove(deviceId);

    // Automatically clear logs for disconnected devices
    clearLogs(deviceId);

    addLog(
      message: 'USB device disconnected: $deviceId',
      level: LogLevel.info,
      step: ProcessStep.systemEvent,
      deviceId: deviceId,
      origin: 'system',
    );
  }

  // Set current batch of serials being processed
  void setCurrentBatch(String batchId, List<String> serials) {
    _currentBatchId = batchId;
    _currentBatchSerials = serials;

    addLog(
      message: 'Batch loaded: $batchId with ${serials.length} devices',
      level: LogLevel.info,
      step: ProcessStep.productBatch,
      deviceId: '',
      origin: 'system',
    );
  }

  // Mark a device as processed in the batch
  void markDeviceProcessed(String serialNumber, bool success) {
    if (_currentBatchSerials.contains(serialNumber)) {
      addLog(
        message: 'Device $serialNumber marked as ${success ? 'successfully' : 'failed to be'} processed',
        level: success ? LogLevel.success : LogLevel.error,
        step: ProcessStep.updateStatus,
        deviceId: serialNumber,
        origin: 'system',
      );
    }
  }

  // Download and store a firmware template
  Future<String?> downloadFirmwareTemplate(
    String templateId,
    String templateUrl,
    String deviceType,
    String version
  ) async {
    try {
      // Create device type directory if it doesn't exist
      final deviceTypeDir = path.join(_firmwareTemplatesDir!, deviceType);
      final directory = Directory(deviceTypeDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Target file path
      final filePath = path.join(deviceTypeDir, '${version.replaceAll('.', '_')}.ino');

      // Log the download start
      addLog(
        message: 'Downloading firmware template: $deviceType v$version',
        level: LogLevel.info,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );

      // Download the template
      final response = await http.get(Uri.parse(templateUrl));
      if (response.statusCode == 200) {
        // Save the template to disk
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        addLog(
          message: 'Firmware template downloaded and saved: $deviceType v$version',
          level: LogLevel.success,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );

        return filePath;
      } else {
        addLog(
          message: 'Failed to download firmware template: HTTP ${response.statusCode}',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return null;
      }
    } catch (e) {
      addLog(
        message: 'Error downloading firmware template: $e',
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );
      return null;
    }
  }

  // Prepare a firmware template by replacing placeholders with actual serial number
  Future<String?> prepareFirmwareTemplate(
    String templatePath,
    String serialNumber,
    String deviceId
  ) async {
    try {
      // Read the template
      final templateFile = File(templatePath);
      if (!await templateFile.exists()) {
        addLog(
          message: 'Template file not found: $templatePath',
          level: LogLevel.error,
          step: ProcessStep.templatePreparation,
          deviceId: deviceId,
          origin: 'system',
        );
        return null;
      }

      // Read template content
      String templateContent = await templateFile.readAsString();

      // Replace placeholders - assuming {{SERIAL_NUMBER}} is the placeholder
      templateContent = templateContent.replaceAll('{{SERIAL_NUMBER}}', serialNumber);

      // Create a temporary file for compilation
      final tempDir = await getTemporaryDirectory();
      final compilePath = path.join(tempDir.path, 'compile_$serialNumber.ino');
      final compileFile = File(compilePath);
      await compileFile.writeAsString(templateContent);

      addLog(
        message: 'Template prepared for device $serialNumber',
        level: LogLevel.success,
        step: ProcessStep.templatePreparation,
        deviceId: deviceId,
        origin: 'system',
      );

      return compilePath;
    } catch (e) {
      addLog(
        message: 'Error preparing template: $e',
        level: LogLevel.error,
        step: ProcessStep.templatePreparation,
        deviceId: deviceId,
        origin: 'system',
      );
      return null;
    }
  }

  // Compile and flash prepared firmware to device
  Future<bool> compileAndFlash(
    String sketchPath,
    String port,
    String fqbn,
    String deviceId
  ) async {
    try {
      // First compile the sketch
      final compileResult = await runProcess(
        'arduino-cli',
        ['compile', '--fqbn', fqbn, sketchPath],
        step: ProcessStep.compile,
        deviceId: deviceId,
      );

      if (compileResult != 0) {
        addLog(
          message: 'Compilation failed with code: $compileResult',
          level: LogLevel.error,
          step: ProcessStep.compile,
          deviceId: deviceId,
          origin: 'system',
        );
        return false;
      }

      // Then upload to device
      final uploadResult = await runProcess(
        'arduino-cli',
        ['upload', '--fqbn', fqbn, '--port', port, sketchPath],
        step: ProcessStep.flash,
        deviceId: deviceId,
      );

      if (uploadResult != 0) {
        addLog(
          message: 'Upload failed with code: $uploadResult',
          level: LogLevel.error,
          step: ProcessStep.flash,
          deviceId: deviceId,
          origin: 'system',
        );
        return false;
      }

      addLog(
        message: 'Firmware successfully compiled and uploaded',
        level: LogLevel.success,
        step: ProcessStep.flash,
        deviceId: deviceId,
        origin: 'system',
      );

      return true;
    } catch (e) {
      addLog(
        message: 'Error during compile and flash: $e',
        level: LogLevel.error,
        step: ProcessStep.flash,
        deviceId: deviceId,
        origin: 'system',
      );
      return false;
    }
  }

  // Kill any active process
  Future<void> killActiveProcess() async {
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill();
      } catch (e) {
        print('Error killing active process: $e');
      }
      _activeProcess = null;
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    await killActiveProcess();
    await stopSerialMonitor();
    await _logStreamController.close();
  }
}