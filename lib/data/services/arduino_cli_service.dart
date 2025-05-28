import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:esp_firmware_tool/data/models/log_entry.dart';

/// Service for interacting with the Arduino CLI
class ArduinoCliService {
  // Current active process (compile, upload, etc.)
  Process? _activeProcess;

  /// Map of device types to their FQBN (Fully Qualified Board Name)
  final Map<String, String> _boardFqbns = {
    'esp32': 'esp32:esp32:esp32',
    'esp8266': 'esp8266:esp8266:generic',
    'arduino_uno': 'arduino:avr:uno',
    'arduino_mega': 'arduino:avr:mega',
    'arduino_nano': 'arduino:avr:nano',
  };

  /// Map to track detected device ports
  final Map<String, String> _devicePorts = {};

  /// Get the FQBN for a specific device type
  String getBoardFqbn(String deviceType) {
    return _boardFqbns[deviceType.toLowerCase()] ?? 'esp32:esp32:esp32'; // Default to ESP32
  }

  /// Get the port for a specific device ID
  Future<String?> getPortForDevice(String deviceId) async {
    // Try to get from cached map first
    if (_devicePorts.containsKey(deviceId)) {
      return _devicePorts[deviceId];
    }

    // Otherwise, try to detect the port by calling Arduino CLI
    try {
      final process = await Process.run(
        'arduino-cli',
        ['board', 'list', '--format', 'json'],
        stdoutEncoding: const Utf8Codec(),
      );

      if (process.exitCode != 0) {
        print('Error detecting boards: ${process.stderr}');
        return null;
      }

      // Parse the JSON output to find the port
      // In a real implementation, you would parse this properly with json.decode
      // and match the device ID to the serial number or other identifier

      // For now, we'll just return a mock port for testing
      final port = deviceId.contains('COM') ? deviceId : 'COM3';
      _devicePorts[deviceId] = port;
      return port;
    } catch (e) {
      print('Exception in getPortForDevice: $e');
      return null;
    }
  }

  /// Run a process and stream its output as logs
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
        print('Running: $commandString');
      }

      // Process stdout with improved line handling
      _activeProcess!.stdout
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              print('[STDOUT] ${line.trim()}');
            }
          }
        });

      // Process stderr
      _activeProcess!.stderr
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              print('[STDERR] ${line.trim()}');
            }
          }
        });

      // Wait for process to complete
      final exitCode = await _activeProcess!.exitCode;

      if (exitCode == 0) {
        print('Process completed successfully');
      } else {
        print('Process failed with exit code: $exitCode');
      }

      _activeProcess = null;
      return exitCode;
    } catch (e) {
      print('Failed to start process: $e');
      return -1;
    }
  }

  /// Kill any active process
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

  /// Check if Arduino CLI is installed and available
  Future<bool> isCliAvailable() async {
    try {
      final process = await Process.run(
        'arduino-cli',
        ['version'],
        stdoutEncoding: const Utf8Codec(),
      );
      return process.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Install required cores for a specific board type
  Future<bool> installCore(String deviceType) async {
    final core = _getCoreForDeviceType(deviceType);
    if (core == null) return false;

    try {
      final process = await Process.run(
        'arduino-cli',
        ['core', 'install', core],
        stdoutEncoding: const Utf8Codec(),
      );
      return process.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Install a library required by a firmware
  Future<bool> installLibrary(String libraryName) async {
    try {
      final process = await Process.run(
        'arduino-cli',
        ['lib', 'install', libraryName],
        stdoutEncoding: const Utf8Codec(),
      );
      return process.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get the Arduino core package for a specific device type
  String? _getCoreForDeviceType(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'esp32':
        return 'esp32:esp32';
      case 'esp8266':
        return 'esp8266:esp8266';
      case 'arduino_uno':
      case 'arduino_mega':
      case 'arduino_nano':
        return 'arduino:avr';
      default:
        return null;
    }
  }

  /// Register a new detected device with its port
  void registerDevice(String deviceId, String port) {
    _devicePorts[deviceId] = port;
  }

  /// Remove a device from the tracked devices
  void unregisterDevice(String deviceId) {
    _devicePorts.remove(deviceId);
  }
}