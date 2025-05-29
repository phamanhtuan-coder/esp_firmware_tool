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

  // Console log process
  Process? _consoleLogProcess;

  // Device currently being monitored
  String? _currentDeviceId;

  // Whether the serial monitor is active
  bool _serialMonitorActive = false;

  // Whether the console log is active
  bool _consoleLogActive = false;

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
    // Handle serial monitor output specifically
    if (origin == 'serial-monitor') {
      addLog(
        message: output.trim(),
        level: LogLevel.serialOutput,
        step: step,
        deviceId: deviceId,
        origin: origin,
        rawOutput: output,
      );
      return;
    }

    // Handle console log output specifically
    if (origin == 'console-log') {
      addLog(
        message: output.trim(),
        level: LogLevel.consoleOutput,
        step: step,
        deviceId: deviceId,
        origin: origin,
        rawOutput: output,
      );
      return;
    }

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

  // Start console log monitoring like in Arduino IDE
  Future<bool> startConsoleLog(String sketchPath, String deviceId) async {
    // Close any existing console log monitor
    await stopConsoleLog();

    try {
      final sketchDirectory = path.dirname(sketchPath);

      // Start Arduino CLI compilation process with verbose output
      _consoleLogProcess = await Process.start(
        'arduino-cli',
        ['compile', '--verbose', '--log-level', 'debug', '-b', getBoardFqbn(deviceId), sketchPath],
        workingDirectory: sketchDirectory,
      );

      _consoleLogActive = true;

      addLog(
        message: 'Console log monitor started for sketch: ${path.basename(sketchPath)}',
        level: LogLevel.info,
        step: ProcessStep.consoleLog,
        deviceId: deviceId,
        origin: 'system',
      );

      // Stream stdout from console log
      _consoleLogProcess!.stdout
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              _processOutput(
                line.trim(),
                ProcessStep.consoleLog,
                deviceId,
                origin: 'console-log'
              );
            }
          }
        });

      // Stream stderr from console log
      _consoleLogProcess!.stderr
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              _processOutput(
                line.trim(),
                ProcessStep.consoleLog,
                deviceId,
                origin: 'console-log'
              );
            }
          }
        });

      // Monitor the process exit
      _consoleLogProcess!.exitCode.then((exitCode) {
        _consoleLogActive = false;
        _consoleLogProcess = null;

        addLog(
          message: 'Console log monitor ended with exit code: $exitCode',
          level: exitCode == 0 ? LogLevel.success : LogLevel.error,
          step: ProcessStep.consoleLog,
          deviceId: deviceId,
          origin: 'system',
        );
      });

      return true;
    } catch (e) {
      addLog(
        message: 'Failed to start console log monitor: $e',
        level: LogLevel.error,
        step: ProcessStep.consoleLog,
        deviceId: deviceId,
        origin: 'system',
      );
      return false;
    }
  }

  // Stop console log monitoring
  Future<void> stopConsoleLog() async {
    if (_consoleLogProcess != null) {
      _consoleLogActive = false;

      try {
        _consoleLogProcess!.kill();
        await _consoleLogProcess!.exitCode;
      } catch (e) {
        addLog(
          message: 'Error stopping console log monitor: $e',
          level: LogLevel.error,
          step: ProcessStep.consoleLog,
          origin: 'system',
        );
      }

      _consoleLogProcess = null;
    }
  }

  // Determine board FQBN based on deviceId (simplified - in real code, look this up from device info)
  String getBoardFqbn(String deviceId) {
    if (deviceId.toLowerCase().contains('esp32')) {
      return 'esp32:esp32:esp32';
    } else if (deviceId.toLowerCase().contains('esp8266')) {
      return 'esp8266:esp8266:generic';
    } else {
      return 'arduino:avr:uno'; // Default to Arduino Uno
    }
  }

  // Start both serial monitor and console log for combined Arduino IDE-like experience
  Future<bool> startArduinoIdeExperience(String port, int baudRate, String sketchPath, String deviceId) async {
    final serialStarted = await startSerialMonitor(port, baudRate, deviceId);
    final consoleStarted = await startConsoleLog(sketchPath, deviceId);

    return serialStarted && consoleStarted;
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

      // Try to kill the process
      try {
        _serialMonitorProcess!.kill();
        await _serialMonitorProcess!.exitCode;
      } catch (e) {
        addLog(
          message: 'Error killing serial monitor: $e',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          deviceId: _currentDeviceId ?? '',
          origin: 'system',
        );
      }

      _serialMonitorProcess = null;
      _currentDeviceId = null;
    }
  }

  // Stop all monitors and close completely
  Future<void> stopAll() async {
    await stopSerialMonitor();
    await stopConsoleLog();
    await killActiveProcess();
  }

  // Kill any active process with improved cleanup
  Future<void> killActiveProcess() async {
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill();
      } catch (e) {
        addLog(
          message: 'Error killing active process: $e',
          level: LogLevel.error,
          step: ProcessStep.systemEvent,
          origin: 'system',
        );
      }
      _activeProcess = null;
    }
  }

  // Dispose of resources
  Future<void> dispose() async {
    await stopAll();

    try {
      await _logStreamController.close();
    } catch (e) {
      print('Error closing log stream controller: $e');
    }
  }
}