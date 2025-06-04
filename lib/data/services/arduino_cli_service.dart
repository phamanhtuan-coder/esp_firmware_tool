import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';

/// Service for interacting with the Arduino CLI
class ArduinoCliService {
  // Current active process (compile, upload, etc.)
  Process? _activeProcess;
  String? _arduinoCliPath;


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
      final process = await startProcess(['board', 'list', '--format', 'json']);

      final stdout = StringBuffer();
      final stderr = StringBuffer();

      process.stdout.transform(utf8.decoder).listen(stdout.write);
      process.stderr.transform(utf8.decoder).listen(stderr.write);

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        print('Error detecting boards: ${stderr.toString()}');
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


  // Initialize the Arduino CLI path
  Future<void> init() async {
    if (_arduinoCliPath != null) return;

    // Get the application documents directory
    final appDir = await getApplicationDocumentsDirectory();
    String appName;
    if (Platform.isWindows) {
      appName = 'arduino-cli';
    } else if (Platform.isMacOS) {
      appName = 'arduino-cli-macos';
    } else if (Platform.isLinux) {
      appName = 'arduino-cli-linux';
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }
    final arduinoDir = Directory(path.join(appDir.path, appName));

    // Create the directory if it doesn't exist
    if (!await arduinoDir.exists()) {
      await arduinoDir.create(recursive: true);
    }

    // Set platform-specific executable path and file name
    String executableName;
    if (Platform.isWindows) {
      executableName = 'arduino-cli.exe';
    } else if (Platform.isMacOS) {
      executableName = 'arduino-cli';
    } else if (Platform.isLinux) {
      executableName = 'arduino-cli';
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }

    // Path to the executable
    _arduinoCliPath = path.join(arduinoDir.path, executableName);

    // Extract executable if it doesn't exist
    if (!await File(_arduinoCliPath!).exists()) {
      // Copy from assets to the app directory
      final byteData = await rootBundle.load('assets/$appName/$executableName');
      final buffer = byteData.buffer;
      await File(_arduinoCliPath!).writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

      // Make the file executable on Unix-based systems
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', _arduinoCliPath!]);
      }
    }
  }

  // Use the Arduino CLI with the proper path
  Future<Process> startProcess(List<String> arguments) async {
    await init(); // Make sure the CLI is initialized
    return Process.start(_arduinoCliPath!, arguments);
  }

  /// Run a process and stream its output as logs
  Future<int> runProcess(
      List<String> arguments, {
        required ProcessStep step,
        String workingDirectory = '',
        String deviceId = '',
        Map<String, String>? environment,
        bool showCommandInLogs = true,
      }) async {
    await init(); // Make sure the CLI is initialized

    try {
      // Kill any existing process
      await killActiveProcess();

      print('DEBUG: Executing command: $_arduinoCliPath ${arguments.join(' ')}');
      if (workingDirectory.isNotEmpty) {
        print('DEBUG: Working directory: $workingDirectory');
      }

      // Start the new process with the proper path
      _activeProcess = await Process.start(
        _arduinoCliPath!,
        arguments,
        workingDirectory: workingDirectory.isNotEmpty ? workingDirectory : null,
        environment: environment,
      );

      if (showCommandInLogs) {
        final commandString = '$_arduinoCliPath ${arguments.join(' ')}';
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
  Future<bool> compileSketch(String sketchPath, String fqbn, {void Function(LogEntry)? onLog}) async {
    try {
      if (onLog != null) {
        onLog(LogEntry(
          message: '🔨 Bắt đầu biên dịch sketch...',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.compile,
          origin: 'arduino-cli',
        ));
      }

      _activeProcess = await startProcess(['compile', '--fqbn', fqbn, '--verbose', sketchPath]);


      // Handle stdout
      _activeProcess!.stdout.transform(utf8.decoder).listen((output) {
        if (onLog != null) {
          // Split output by lines to handle each line separately
          for (var line in output.split('\n')) {
            if (line.trim().isNotEmpty) {
              onLog(LogEntry(
                message: line,
                timestamp: DateTime.now(),
                level: _getLogLevelFromOutput(line),
                step: ProcessStep.compile,
                origin: 'arduino-cli',
                rawOutput: line,
              ));
            }
          }
        }
      });

      // Handle stderr
      _activeProcess!.stderr.transform(utf8.decoder).listen((output) {
        if (onLog != null) {
          for (var line in output.split('\n')) {
            if (line.trim().isNotEmpty) {
              onLog(LogEntry(
                message: line,
                timestamp: DateTime.now(),
                level: LogLevel.error,
                step: ProcessStep.compile,
                origin: 'arduino-cli',
                rawOutput: line,
              ));
            }
          }
        }
      });

      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;

      if (exitCode == 0) {
        if (onLog != null) {
          onLog(LogEntry(
            message: '✅ Biên dịch thành công',
            timestamp: DateTime.now(),
            level: LogLevel.success,
            step: ProcessStep.compile,
            origin: 'arduino-cli',
          ));
        }
        return true;
      } else {
        if (onLog != null) {
          onLog(LogEntry(
            message: '❌ Biên dịch thất bại (exit code: $exitCode)',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.compile,
            origin: 'arduino-cli',
          ));
        }
        return false;
      }

    } catch (e) {
      if (onLog != null) {
        onLog(LogEntry(
          message: '❌ Lỗi trong quá trình biên dịch: $e',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.compile,
          origin: 'arduino-cli',
        ));
      }
      return false;
    }
  }

  /// Upload a sketch using arduino-cli
  Future<bool> uploadSketch(String sketchPath, String port, String fqbn, {void Function(LogEntry)? onLog}) async {
    try {
      if (onLog != null) {
        onLog(LogEntry(
          message: '📤 Bắt đầu upload sketch...',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.flash,
          origin: 'arduino-cli',
        ));
      }

      _activeProcess = await startProcess(['upload', '-p', port, '--fqbn', fqbn, '--verbose', sketchPath]);


      // Handle stdout
      _activeProcess!.stdout.transform(utf8.decoder).listen((output) {
        if (onLog != null) {
          for (var line in output.split('\n')) {
            if (line.trim().isNotEmpty) {
              onLog(LogEntry(
                message: line,
                timestamp: DateTime.now(),
                level: _getLogLevelFromOutput(line),
                step: ProcessStep.flash,
                origin: 'arduino-cli',
                rawOutput: line,
              ));
            }
          }
        }
      });

      // Handle stderr
      _activeProcess!.stderr.transform(utf8.decoder).listen((output) {
        if (onLog != null) {
          for (var line in output.split('\n')) {
            if (line.trim().isNotEmpty) {
              onLog(LogEntry(
                message: line,
                timestamp: DateTime.now(),
                level: LogLevel.error,
                step: ProcessStep.flash,
                origin: 'arduino-cli',
                rawOutput: line,
              ));
            }
          }
        }
      });

      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;

      if (exitCode == 0) {
        if (onLog != null) {
          onLog(LogEntry(
            message: '✅ Upload thành công',
            timestamp: DateTime.now(),
            level: LogLevel.success,
            step: ProcessStep.flash,
            origin: 'arduino-cli',
          ));
        }
        return true;
      } else {
        if (onLog != null) {
          onLog(LogEntry(
            message: '❌ Upload thất bại (exit code: $exitCode)',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.flash,
            origin: 'arduino-cli',
          ));
        }
        return false;
      }

    } catch (e) {
      if (onLog != null) {
        onLog(LogEntry(
          message: '❌ Lỗi trong quá trình upload: $e',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.flash,
          origin: 'arduino-cli',
        ));
      }
      return false;
    }
  }

  LogLevel _getLogLevelFromOutput(String output) {
    final lower = output.toLowerCase();
    if (lower.contains('error') || lower.contains('failed')) {
      return LogLevel.error;
    } else if (lower.contains('warning')) {
      return LogLevel.warning;
    } else if (lower.contains('success') ||
              lower.contains('done') ||
              lower.contains('uploaded') ||
              (lower.contains('bytes') && lower.contains('written'))) {
      return LogLevel.success;
    } else if (lower.contains('avrdude') ||
              lower.contains('compiling') ||
              lower.contains('writing') ||
              lower.contains('reading')) {
      return LogLevel.verbose;
    }
    return LogLevel.info;
  }

  /// Check if Arduino CLI is installed and available
  Future<bool> isCliAvailable() async {
    try {
      print('DEBUG: Checking Arduino CLI availability...');
      final process = await startProcess(['version']);

      final stdout = StringBuffer();
      final stderr = StringBuffer();

      process.stdout.transform(utf8.decoder).listen(stdout.write);
      process.stderr.transform(utf8.decoder).listen(stderr.write);

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        print('DEBUG: Arduino CLI is available. Version info:');
        print(stdout);
        return true;
      } else {
        print('DEBUG: Arduino CLI check failed with exit code $exitCode');
        print('Error output: $stderr');
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
      final process = await startProcess(['core', 'install', core]);

      final exitCode = await process.exitCode;
      return exitCode == 0;
    } catch (e) {
      print('Error installing core: $e');
      return false;
    }
  }

  /// Install a library required by a firmware
  Future<bool> installLibrary(String libraryName) async {
    try {
      final process = await startProcess(['lib', 'install', libraryName]);
      final stdout = StringBuffer();
      final stderr = StringBuffer();

      process.stdout.transform(utf8.decoder).listen(stdout.write);
      process.stderr.transform(utf8.decoder).listen(stderr.write);

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        print('Failed to install library: ${stderr.toString()}');
      }
      return exitCode == 0;
    } catch (e) {
      print('Error installing library: $e');
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

