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
    'arduino_uno_r3': 'arduino:avr:uno', // Add Arduino UNO R3
  };

  /// Get the Arduino core package for a specific device type
  String? _getCoreForDeviceType(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'esp32':
        return 'esp32:esp32';
      case 'esp8266':
        return 'esp8266:esp8266';
      case 'arduino_uno':
      case 'arduino_uno_r3': // Add Arduino UNO R3
      case 'arduino_mega':
      case 'arduino_nano':
        return 'arduino:avr';
      default:
        return null;
    }
  }
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

      print('DEBUG: Executing command: $executable ${arguments.join(' ')}');
      if (workingDirectory.isNotEmpty) {
        print('DEBUG: Working directory: $workingDirectory');
      }

      // Start the new process
      _activeProcess = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory.isNotEmpty ? workingDirectory : null,
        environment: environment,
      );

      if (showCommandInLogs) {
        final commandString = '$executable ${arguments.join(' ')}';
        print('Running command: $commandString');
      }

      // Stream stdout with improved line handling
      _activeProcess!.stdout
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              print('[STDOUT] $line');
            }
          }
        }, onError: (error) {
          print('Error in stdout stream: $error');
        });

      // Stream stderr
      _activeProcess!.stderr
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              print('[STDERR] $line');
            }
          }
        }, onError: (error) {
          print('Error in stderr stream: $error');
        });

      // Wait for process to complete
      final exitCode = await _activeProcess!.exitCode;
      print('DEBUG: Process completed with exit code: $exitCode');

      _activeProcess = null;
      return exitCode;
    } catch (e, stackTrace) {
      print('DEBUG: Process execution failed:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
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

  /// Compile a sketch using arduino-cli
  Future<bool> compileSketch(String sketchPath, String fqbn) async {
    print('DEBUG: Compiling sketch at $sketchPath');
    print('DEBUG: Using FQBN: $fqbn');

    // Get the directory and filename separately
    final sketchFile = File(sketchPath);
    final sketchDir = sketchFile.parent;
    final sketchName = sketchFile.path;

    print('DEBUG: Sketch directory: ${sketchDir.path}');
    print('DEBUG: Sketch name: $sketchName');

    final exitCode = await runProcess(
      'arduino-cli',
      ['compile', '--fqbn', fqbn, '--verbose', sketchName],
      step: ProcessStep.compile,
      showCommandInLogs: true,
      workingDirectory: sketchDir.path,
    );

    final success = exitCode == 0;
    print('DEBUG: Compilation ${success ? 'succeeded' : 'failed'} with exit code $exitCode');
    return success;
  }

  /// Upload a sketch to a board using arduino-cli
  Future<bool> uploadSketch(String sketchPath, String port, String fqbn) async {
    print('DEBUG: Uploading sketch to port $port');
    print('DEBUG: Using FQBN: $fqbn');
    print('DEBUG: Sketch path: $sketchPath');

    // Get the directory and filename separately
    final sketchFile = File(sketchPath);
    final sketchDir = sketchFile.parent;
    final sketchName = sketchFile.path;

    print('DEBUG: Sketch directory: ${sketchDir.path}');
    print('DEBUG: Sketch name: $sketchName');

    final exitCode = await runProcess(
      'arduino-cli',
      ['upload', '-p', port, '--fqbn', fqbn, '--verbose', sketchName],
      step: ProcessStep.flash,
      showCommandInLogs: true,
      workingDirectory: sketchDir.path,
    );

    final success = exitCode == 0;
    print('DEBUG: Upload ${success ? 'succeeded' : 'failed'} with exit code $exitCode');
    return success;
  }

  /// Check if Arduino CLI is installed and available
  Future<bool> isCliAvailable() async {
    try {
      print('DEBUG: Checking Arduino CLI availability...');
      final result = await Process.run('arduino-cli', ['version']);

      if (result.exitCode == 0) {
        print('DEBUG: Arduino CLI is available. Version info:');
        print(result.stdout);
        return true;
      } else {
        print('DEBUG: Arduino CLI check failed with exit code ${result.exitCode}');
        print('Error output: ${result.stderr}');
        return false;
      }
    } catch (e) {
      print('DEBUG: Arduino CLI availability check failed: $e');
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

  /// Register a new detected device with its port
  void registerDevice(String deviceId, String port) {
    _devicePorts[deviceId] = port;
  }

  /// Remove a device from the tracked devices
  void unregisterDevice(String deviceId) {
    _devicePorts.remove(deviceId);
  }
}