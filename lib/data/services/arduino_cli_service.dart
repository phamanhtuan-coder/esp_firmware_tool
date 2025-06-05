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
    try {
      print('======= ARDUINO CLI INITIALIZATION =======');
      if (_arduinoCliPath != null) {
        print('DEBUG: Arduino CLI already initialized at: $_arduinoCliPath');
        return;
      }

      // Get the application documents directory
      print('DEBUG: Getting application directory');
      final appDir = await getApplicationDocumentsDirectory();
      print('DEBUG: App directory: ${appDir.path}');

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
      print('DEBUG: App name based on platform: $appName');

      final arduinoDir = Directory(path.join(appDir.path, appName));
      print('DEBUG: Arduino CLI directory path: ${arduinoDir.path}');

      // Create the directory if it doesn't exist
      if (!await arduinoDir.exists()) {
        print('DEBUG: Creating Arduino CLI directory');
        await arduinoDir.create(recursive: true);
      } else {
        print('DEBUG: Arduino CLI directory already exists');
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
      print('DEBUG: Executable name: $executableName');

      // Path to the executable
      _arduinoCliPath = path.join(arduinoDir.path, executableName);
      print('DEBUG: Arduino CLI executable path: $_arduinoCliPath');

      // Extract executable if it doesn't exist
      final cliFile = File(_arduinoCliPath!);
      if (!await cliFile.exists()) {
        print('DEBUG: Arduino CLI executable does not exist, extracting from assets');
        try {
          // Check if the asset exists
          final assetPath = 'assets/$appName/$executableName';
          print('DEBUG: Loading asset from: $assetPath');

          try {
            // Copy from assets to the app directory
            final byteData = await rootBundle.load(assetPath);
            print('DEBUG: Asset loaded successfully, size: ${byteData.lengthInBytes} bytes');

            final buffer = byteData.buffer;
            await cliFile.writeAsBytes(
              buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
            );
            print('DEBUG: Successfully extracted Arduino CLI');

            // Make the file executable on Unix-based systems
            if (!Platform.isWindows) {
              print('DEBUG: Setting executable permissions');
              await Process.run('chmod', ['+x', _arduinoCliPath!]);
            }
          } catch (e) {
            print('ERROR: Failed to load asset: $e');

            // List available assets for debugging
            print('DEBUG: Checking for available assets...');
            try {
              final manifestContent = await rootBundle.loadString('AssetManifest.json');
              final Map<String, dynamic> manifestMap = json.decode(manifestContent);
              print('DEBUG: Available assets:');
              manifestMap.keys.where((k) => k.startsWith('assets/')).forEach((k) {
                print('  - $k');
              });
            } catch (e) {
              print('ERROR: Failed to list assets: $e');
            }

            throw Exception('Failed to extract Arduino CLI: $e');
          }
        } catch (e) {
          print('DEBUG: Error extracting Arduino CLI: $e');
          throw Exception('Failed to extract Arduino CLI: $e');
        }
      } else {
        print('DEBUG: Arduino CLI executable already exists');
      }

      // Verify the CLI is working
      try {
        print('DEBUG: Verifying Arduino CLI by running "version" command');
        final result = await Process.run(_arduinoCliPath!, ['version']);
        if (result.exitCode == 0) {
          print('DEBUG: Arduino CLI verified working. Version info:');
          print(result.stdout);
        } else {
          print('DEBUG: Arduino CLI verification failed:');
          print(result.stderr);
          throw Exception('Arduino CLI verification failed with exit code: ${result.exitCode}');
        }
      } catch (e) {
        print('DEBUG: Error verifying Arduino CLI: $e');
        throw Exception('Error verifying Arduino CLI: $e');
      }
      print('======= ARDUINO CLI INITIALIZATION COMPLETED =======');
    } catch (e) {
      print('CRITICAL ERROR: Error in init(): $e');
      throw Exception('Failed to initialize Arduino CLI: $e');
    }
  }

  /// Initialize Arduino CLI by copying binary to temp directory and installing required cores
  Future<bool> initialize() async {
    try {
      // Get the platform-specific Arduino CLI binary name
      String binaryName = Platform.isWindows ? 'arduino-cli.exe' : 'arduino-cli';
      String assetPath = Platform.isWindows ? 'arduino-cli/${binaryName}' :
                        Platform.isMacOS ? 'arduino-cli-macos/${binaryName}' :
                        'arduino-cli-linux/${binaryName}';

      // Get temp directory for extracting Arduino CLI
      final tempDir = await getTemporaryDirectory();
      final cliPath = path.join(tempDir.path, binaryName);
      _arduinoCliPath = cliPath;

      // Copy Arduino CLI binary from assets if not already present
      if (!await File(cliPath).exists()) {
        final byteData = await rootBundle.load('assets/$assetPath');
        final buffer = byteData.buffer;
        await File(cliPath).writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)
        );

        // Make the binary executable on Unix systems
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', cliPath]);
        }
      }

      // Update index
      await Process.run(cliPath, ['core', 'update-index']);

      // Install required cores if not already installed
      for (final type in _boardFqbns.keys) {
        final core = _getCoreForDeviceType(type);
        if (core != null) {
          await Process.run(cliPath, ['core', 'install', core]);
        }
      }

      return true;
    } catch (e) {
      print('Failed to initialize Arduino CLI: $e');
      return false;
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
      print('DEBUG: Starting compile for sketch: $sketchPath with FQBN: $fqbn');
      if (onLog != null) {
        onLog(LogEntry(
          message: '🔨 Starting compilation...',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.firmwareCompile,
          origin: 'arduino-cli',
        ));
      }

      // Kill any existing process first
      await killActiveProcess();

      // Start compilation process
      _activeProcess = await startProcess([
        'compile',
        '--fqbn', fqbn,
        '--verbose',
        sketchPath,
      ]);

      final stdout = StringBuffer();
      final stderr = StringBuffer();

      // Handle stdout stream
      _activeProcess!.stdout.transform(utf8.decoder).listen(
        (data) {
          stdout.write(data);
          if (onLog != null) {
            final lines = data.split('\n');
            for (var line in lines) {
              if (line.trim().isNotEmpty) {
                onLog(LogEntry(
                  message: line.trim(),
                  timestamp: DateTime.now(),
                  level: _getLogLevelFromOutput(line),
                  step: ProcessStep.firmwareCompile,
                  origin: 'arduino-cli',
                  rawOutput: line,
                ));
              }
            }
          }
        },
      );

      // Handle stderr stream
      _activeProcess!.stderr.transform(utf8.decoder).listen(
        (data) {
          stderr.write(data);
          if (onLog != null) {
            final lines = data.split('\n');
            for (var line in lines) {
              if (line.trim().isNotEmpty) {
                onLog(LogEntry(
                  message: line.trim(),
                  timestamp: DateTime.now(),
                  level: LogLevel.error,
                  step: ProcessStep.firmwareCompile,
                  origin: 'arduino-cli',
                  rawOutput: line,
                ));
              }
            }
          }
        },
      );

      // Wait for process to complete
      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;

      if (exitCode == 0) {
        if (onLog != null) {
          onLog(LogEntry(
            message: '✅ Compilation successful',
            timestamp: DateTime.now(),
            level: LogLevel.success,
            step: ProcessStep.firmwareCompile,
            origin: 'arduino-cli',
          ));
        }
        return true;
      } else {
        final errorMessage = stderr.toString().trim();
        if (onLog != null) {
          onLog(LogEntry(
            message: '❌ Compilation failed (exit code: $exitCode)\n$errorMessage',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.firmwareCompile,
            origin: 'arduino-cli',
          ));
        }
        return false;
      }
    } catch (e) {
      print('DEBUG: Compile error: $e');
      if (onLog != null) {
        onLog(LogEntry(
          message: '❌ Error during compilation: $e',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.firmwareCompile,
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
          message: '📤 Starting upload...',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.flash,
          origin: 'arduino-cli',
        ));
      }

      // Kill any existing process first
      await killActiveProcess();

      // Start upload process
      _activeProcess = await startProcess([
        'upload',
        '-p', port,
        '--fqbn', fqbn,
        '--verbose',
        sketchPath,
      ]);

      final stdout = StringBuffer();
      final stderr = StringBuffer();

      // Handle stdout stream
      _activeProcess!.stdout.transform(utf8.decoder).listen(
        (data) {
          stdout.write(data);
          if (onLog != null) {
            final lines = data.split('\n');
            for (var line in lines) {
              if (line.trim().isNotEmpty) {
                onLog(LogEntry(
                  message: line.trim(),
                  timestamp: DateTime.now(),
                  level: _getLogLevelFromOutput(line),
                  step: ProcessStep.flash,
                  origin: 'arduino-cli',
                  rawOutput: line,
                ));
              }
            }
          }
        },
      );

      // Handle stderr stream
      _activeProcess!.stderr.transform(utf8.decoder).listen(
        (data) {
          stderr.write(data);
          if (onLog != null) {
            final lines = data.split('\n');
            for (var line in lines) {
              if (line.trim().isNotEmpty) {
                onLog(LogEntry(
                  message: line.trim(),
                  timestamp: DateTime.now(),
                  level: LogLevel.error,
                  step: ProcessStep.flash,
                  origin: 'arduino-cli',
                  rawOutput: line,
                ));
              }
            }
          }
        },
      );

      // Wait for process to complete
      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;

      if (exitCode == 0) {
        if (onLog != null) {
          onLog(LogEntry(
            message: '✅ Upload successful',
            timestamp: DateTime.now(),
            level: LogLevel.success,
            step: ProcessStep.flash,
            origin: 'arduino-cli',
          ));
        }
        return true;
      } else {
        final errorMessage = stderr.toString().trim();
        if (onLog != null) {
          onLog(LogEntry(
            message: '❌ Upload failed (exit code: $exitCode)\n$errorMessage',
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
          message: '❌ Error during upload: $e',
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

