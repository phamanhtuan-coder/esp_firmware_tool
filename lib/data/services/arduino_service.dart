import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/domain/repositories/arduino_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class ArduinoService implements ArduinoRepository {
  final LogService _logService = GetIt.instance<LogService>();
  Process? _activeProcess;
  String? _arduinoCliPath;

  final Map<String, String> _boardFqbns = {
    'esp32': 'esp32:esp32:esp32',
    'esp8266': 'esp8266:esp8266:generic',
    'arduino_uno': 'arduino:avr:uno',
    'arduino_mega': 'arduino:avr:mega',
    'arduino_nano': 'arduino:avr:nano',
    'arduino_uno_r3': 'arduino:avr:uno',
  };

  String? _getCoreForDeviceType(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'esp32':
        return 'esp32:esp32';
      case 'esp8266':
        return 'esp8266:esp8266';
      case 'arduino_uno':
      case 'arduino_uno_r3':
      case 'arduino_mega':
      case 'arduino_nano':
        return 'arduino:avr';
      default:
        return null;
    }
  }

  @override
  Future<bool> initialize() async {
    try {
      if (_arduinoCliPath != null) return true;

      final appDir = await getApplicationDocumentsDirectory();
      String appName =
          Platform.isWindows
              ? 'arduino-cli'
              : Platform.isMacOS
              ? 'arduino-cli-macos'
              : 'arduino-cli-linux';
      String executableName =
          Platform.isWindows ? 'arduino-cli.exe' : 'arduino-cli';
      final arduinoDir = Directory(path.join(appDir.path, appName));
      if (!await arduinoDir.exists()) {
        await arduinoDir.create(recursive: true);
      }

      _arduinoCliPath = path.join(arduinoDir.path, executableName);
      final cliFile = File(_arduinoCliPath!);
      if (!await cliFile.exists()) {
        final byteData = await rootBundle.load(
          'assets/$appName/$executableName',
        );
        final buffer = byteData.buffer;
        await cliFile.writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', _arduinoCliPath!]);
        }
      }

      final result = await Process.run(_arduinoCliPath!, ['version']);
      if (result.exitCode != 0) {
        _logService.addLog(
          message: 'Arduino CLI verification failed: ${result.stderr}',
          level: LogLevel.error,
          step: ProcessStep.systemStart,
          origin: 'arduino-cli',
        );
        return false;
      }

      await Process.run(_arduinoCliPath!, ['core', 'update-index']);
      for (final type in _boardFqbns.keys) {
        final core = _getCoreForDeviceType(type);
        if (core != null) {
          await Process.run(_arduinoCliPath!, ['core', 'install', core]);
        }
      }

      _logService.addLog(
        message: 'Arduino CLI initialized successfully',
        level: LogLevel.success,
        step: ProcessStep.systemStart,
        origin: 'arduino-cli',
      );
      return true;
    } catch (e) {
      _logService.addLog(
        message: 'Failed to initialize Arduino CLI: $e',
        level: LogLevel.error,
        step: ProcessStep.systemStart,
        origin: 'arduino-cli',
      );
      return false;
    }
  }

  @override
  Future<bool> compileSketch(String sketchPath, String fqbn) async {
    try {
      _logService.addLog(
        message: 'Starting compilation for sketch: $sketchPath',
        level: LogLevel.info,
        step: ProcessStep.firmwareCompile,
        origin: 'arduino-cli',
      );

      await _killActiveProcess();
      _activeProcess = await Process.start(_arduinoCliPath!, [
        'compile',
        '--fqbn',
        fqbn,
        '--verbose',
        sketchPath,
      ]);

      final stdout = StringBuffer();
      final stderr = StringBuffer();

      _activeProcess!.stdout.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n');
        for (var line in lines) {
          if (line.trim().isNotEmpty) {
            _logService.addLog(
              message: line.trim(),
              level: _getLogLevelFromOutput(line),
              step: ProcessStep.firmwareCompile,
              origin: 'arduino-cli',
              rawOutput: line,
            );
          }
        }
        stdout.write(data);
      });

      _activeProcess!.stderr.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n');
        for (var line in lines) {
          if (line.trim().isNotEmpty) {
            _logService.addLog(
              message: line.trim(),
              level: LogLevel.error,
              step: ProcessStep.firmwareCompile,
              origin: 'arduino-cli',
              rawOutput: line,
            );
          }
        }
        stderr.write(data);
      });

      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;

      if (exitCode == 0) {
        _logService.addLog(
          message: 'Compilation successful',
          level: LogLevel.success,
          step: ProcessStep.firmwareCompile,
          origin: 'arduino-cli',
        );
        return true;
      } else {
        _logService.addLog(
          message:
              'Compilation failed (exit code: $exitCode)\n${stderr.toString().trim()}',
          level: LogLevel.error,
          step: ProcessStep.firmwareCompile,
          origin: 'arduino-cli',
        );
        return false;
      }
    } catch (e) {
      _logService.addLog(
        message: 'Error during compilation: $e',
        level: LogLevel.error,
        step: ProcessStep.firmwareCompile,
        origin: 'arduino-cli',
      );
      return false;
    }
  }

  @override
  Future<bool> uploadSketch(String sketchPath, String port, String fqbn) async {
    try {
      if (!await _validatePortAccess(port)) {
        _logService.addLog(
          message:
              'Cannot access port $port. Check if another program is using it or if permissions are sufficient.',
          level: LogLevel.error,
          step: ProcessStep.flash,
          origin: 'arduino-cli',
        );
        return false;
      }

      _logService.addLog(
        message: 'Starting upload to $port...',
        level: LogLevel.info,
        step: ProcessStep.flash,
        origin: 'arduino-cli',
      );

      await _killActiveProcess();
      if (Platform.isWindows) {
        await Process.run('mode', [port]);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _activeProcess = await Process.start(_arduinoCliPath!, [
        'upload',
        '-p',
        port,
        '--fqbn',
        fqbn,
        '--verbose',
        sketchPath,
      ]);

      final stdout = StringBuffer();
      final stderr = StringBuffer();

      _activeProcess!.stdout.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n');
        for (var line in lines) {
          if (line.trim().isNotEmpty) {
            _logService.addLog(
              message: line.trim(),
              level: _getLogLevelFromOutput(line),
              step: ProcessStep.flash,
              origin: 'arduino-cli',
              rawOutput: line,
            );
          }
        }
        stdout.write(data);
      });

      _activeProcess!.stderr.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n');
        for (var line in lines) {
          if (line.trim().isNotEmpty) {
            _logService.addLog(
              message: line.trim(),
              level: LogLevel.error,
              step: ProcessStep.flash,
              origin: 'arduino-cli',
              rawOutput: line,
            );
          }
        }
        stderr.write(data);
      });

      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;

      if (exitCode == 0) {
        _logService.addLog(
          message: 'Upload successful',
          level: LogLevel.success,
          step: ProcessStep.flash,
          origin: 'arduino-cli',
        );
        return true;
      } else {
        _logService.addLog(
          message:
              'Upload failed (exit code: $exitCode)\n${stderr.toString().trim()}',
          level: LogLevel.error,
          step: ProcessStep.flash,
          origin: 'arduino-cli',
        );
        return false;
      }
    } catch (e) {
      _logService.addLog(
        message: 'Error during upload: $e',
        level: LogLevel.error,
        step: ProcessStep.flash,
        origin: 'arduino-cli',
      );
      return false;
    }
  }

  Future<bool> compileAndFlash({
    required String sketchPath,
    required String port,
    required String deviceId,
    String deviceType = 'esp32',
    String? batchId,
    Map<String, String>? placeholders,
  }) async {
    try {
      _logService.addLog(
        message: 'Starting firmware flash process for device $deviceId',
        level: LogLevel.info,
        step: ProcessStep.flash,
        deviceId: deviceId,
        origin: 'system',
      );

      // Get board FQBN for device type
      final fqbn = _boardFqbns[deviceType.toLowerCase()] ?? _boardFqbns['esp32']!;

      // Validate port access before proceeding
      if (!await _validatePortAccess(port)) {
        throw Exception('Cannot access port $port. Please check connections and permissions.');
      }

      // First compile the sketch
      _logService.addLog(
        message: 'Compiling firmware for device $deviceId',
        level: LogLevel.info,
        step: ProcessStep.firmwareCompile,
        deviceId: deviceId,
        origin: 'system',
      );

      final compileSuccess = await compileSketch(sketchPath, fqbn);
      if (!compileSuccess) {
        throw Exception('Firmware compilation failed');
      }

      _logService.addLog(
        message: 'Compilation successful, starting upload...',
        level: LogLevel.success,
        step: ProcessStep.firmwareCompile,
        deviceId: deviceId,
        origin: 'system',
      );

      // Then upload to device
      _logService.addLog(
        message: 'Uploading firmware to device $deviceId on port $port',
        level: LogLevel.info,
        step: ProcessStep.flash,
        deviceId: deviceId,
        origin: 'system',
      );

      final uploadSuccess = await uploadSketch(sketchPath, port, fqbn);
      if (!uploadSuccess) {
        throw Exception('Firmware upload failed');
      }

      _logService.addLog(
        message: '✅ Firmware successfully flashed to device $deviceId',
        level: LogLevel.success,
        step: ProcessStep.flash,
        deviceId: deviceId,
        origin: 'system',
      );

      return true;
    } catch (e, stackTrace) {
      _logService.addLog(
        message: 'Error during firmware flash: $e\n$stackTrace',
        level: LogLevel.error,
        step: ProcessStep.flash,
        deviceId: deviceId,
        origin: 'system',
      );
      return false;
    } finally {
      await _killActiveProcess();
    }
  }

  Future<String?> prepareFirmwareTemplate(
    String sourcePath,
    String serialNumber,
    String deviceId, {
    Map<String, String>? placeholders,
  }) async {
    try {
      if (!await File(sourcePath).exists()) {
        throw Exception('Source file not found: $sourcePath');
      }

      _logService.addLog(
        message: 'Preparing firmware template for device $deviceId',
        level: LogLevel.info,
        step: ProcessStep.templatePreparation,
        deviceId: deviceId,
        origin: 'system',
      );

      // Create temp directory
      final tempDir = await getTemporaryDirectory();
      final sketchName = 'firmware_${serialNumber}_${DateTime.now().millisecondsSinceEpoch}';
      final sketchDir = Directory(path.join(tempDir.path, sketchName));
      await sketchDir.create(recursive: true);

      // Copy source to temp location
      final tempPath = path.join(sketchDir.path, '$sketchName.ino');
      String content = await File(sourcePath).readAsString();

      // Replace placeholders
      if (placeholders != null) {
        for (final entry in placeholders.entries) {
          content = content.replaceAll('{{${entry.key}}}', entry.value);
        }
      }

      // Handle special defines for SERIAL_NUMBER and DEVICE_ID
      content = _processDefines(content, serialNumber, deviceId);

      // Write processed content
      await File(tempPath).writeAsString(content);

      _logService.addLog(
        message: 'Template prepared successfully',
        level: LogLevel.success,
        step: ProcessStep.templatePreparation,
        deviceId: deviceId,
        origin: 'system',
      );

      return tempPath;
    } catch (e, stackTrace) {
      _logService.addLog(
        message: 'Error preparing template: $e\n$stackTrace',
        level: LogLevel.error,
        step: ProcessStep.templatePreparation,
        deviceId: deviceId,
        origin: 'system',
      );
      return null;
    }
  }

  String _processDefines(String content, String serialNumber, String deviceId) {
    // Handle #define SERIAL_NUMBER and DEVICE_ID
    final definePattern = RegExp(r'#define\s+(SERIAL_NUMBER|DEVICE_ID)\s+"?([^"\n\r]+)"?');
    return content.replaceAllMapped(definePattern, (match) {
      final defineName = match.group(1);
      final value = defineName == 'SERIAL_NUMBER' ? serialNumber : deviceId;
      return '#define $defineName "$value"';
    });
  }

  @override
  Future<List<String>> getAvailablePorts() async {
    try {
      List<String> ports = [];

      // Sử dụng libserialport để lấy danh sách cổng
      final availablePorts = SerialPort.availablePorts;
      if (availablePorts.isNotEmpty) {
        ports.addAll(availablePorts);
        _logService.addLog(
          message: 'Found ${ports.length} ports via libserialport: ${ports.join(", ")}',
          level: LogLevel.success,
          step: ProcessStep.usbCheck,
          origin: 'system',
        );
        return ports;
      }

      // Backup method: Manual COM port check on Windows
      if (Platform.isWindows) {
        for (int i = 1; i <= 20; i++) {
          final port = 'COM$i';
          try {
            final serialPort = SerialPort(port);
            if (serialPort.openReadWrite()) {
              ports.add(port);
              serialPort.close();
            }
          } catch (e) {
            // Skip if port cannot be accessed
          }
        }

        if (ports.isNotEmpty) {
          _logService.addLog(
            message: 'Found ${ports.length} available COM ports: ${ports.join(", ")}',
            level: LogLevel.success,
            step: ProcessStep.usbCheck,
            origin: 'system',
          );
          return ports;
        }
      }

      _logService.addLog(
        message: 'No ports found',
        level: LogLevel.warning,
        step: ProcessStep.usbCheck,
        origin: 'system',
      );
      return [];

    } catch (e) {
      _logService.addLog(
        message: 'Error detecting ports: $e',
        level: LogLevel.error,
        step: ProcessStep.usbCheck,
        origin: 'system',
      );
      return [];
    }
  }

  @override
  Future<bool> installCore(String deviceType) async {
    final core = _getCoreForDeviceType(deviceType);
    if (core == null) {
      _logService.addLog(
        message: 'Unsupported device type: $deviceType',
        level: LogLevel.error,
        step: ProcessStep.installCore,
        origin: 'arduino-cli',
      );
      return false;
    }
    try {
      final process = await Process.start(_arduinoCliPath!, [
        'core',
        'install',
        core,
      ]);
      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        _logService.addLog(
          message: 'Installed core for $deviceType',
          level: LogLevel.success,
          step: ProcessStep.installCore,
          origin: 'arduino-cli',
        );
        return true;
      } else {
        _logService.addLog(
          message: 'Failed to install core for $deviceType',
          level: LogLevel.error,
          step: ProcessStep.installCore,
          origin: 'arduino-cli',
        );
        return false;
      }
    } catch (e) {
      _logService.addLog(
        message: 'Error installing core: $e',
        level: LogLevel.error,
        step: ProcessStep.installCore,
        origin: 'arduino-cli',
      );
      return false;
    }
  }

  @override
  Future<bool> installLibrary(String libraryName) async {
    try {
      final process = await Process.start(_arduinoCliPath!, [
        'lib',
        'install',
        libraryName,
      ]);
      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        _logService.addLog(
          message: 'Installed library $libraryName',
          level: LogLevel.success,
          step: ProcessStep.installLibrary,
          origin: 'arduino-cli',
        );
        return true;
      } else {
        _logService.addLog(
          message: 'Failed to install library $libraryName',
          level: LogLevel.error,
          step: ProcessStep.installLibrary,
          origin: 'arduino-cli',
        );
        return false;
      }
    } catch (e) {
      _logService.addLog(
        message: 'Error installing library: $e',
        level: LogLevel.error,
        step: ProcessStep.installLibrary,
        origin: 'arduino-cli',
      );
      return false;
    }
  }

  Future<bool> _validatePortAccess(String port) async {
    try {
      final process = await Process.start(_arduinoCliPath!, [
        'board',
        'list',
        '--format',
        'json',
      ]);
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        _logService.addLog(
          message: 'Port validation failed for $port',
          level: LogLevel.error,
          step: ProcessStep.usbCheck,
          origin: 'arduino-cli',
        );
        return false;
      }
      if (Platform.isWindows) {
        try {
          await Process.run('net', ['stop', 'SerialPort']);
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          _logService.addLog(
            message: 'Error releasing port: $e',
            level: LogLevel.error,
            step: ProcessStep.usbCheck,
            origin: 'arduino-cli',
          );
        }
      }
      return true;
    } catch (e) {
      _logService.addLog(
        message: 'Port validation error: $e',
        level: LogLevel.error,
        step: ProcessStep.usbCheck,
        origin: 'arduino-cli',
      );
      return false;
    }
  }

  Timer? _portScanTimer;
  final _portChangeController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get portChanges => _portChangeController.stream;
  List<String> _lastPorts = [];

  // Start continuous port scanning
  void startPortScanning() {
    _portScanTimer?.cancel();
    _portScanTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final ports = await getAvailablePorts();
        if (!_portsEqual(ports, _lastPorts)) {
          _lastPorts = ports;
          _portChangeController.add(ports);

          _logService.addLog(
            message: 'Detected port changes: ${ports.join(", ")}',
            level: LogLevel.info,
            step: ProcessStep.usbCheck,
            origin: 'arduino-cli',
          );
        }
      } catch (e) {
        _logService.addLog(
          message: 'Port scanning error: $e',
          level: LogLevel.error,
          step: ProcessStep.usbCheck,
          origin: 'arduino-cli',
        );
      }
    });
  }

  bool _portsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void stopPortScanning() {
    _portScanTimer?.cancel();
    _portScanTimer = null;
  }

  void dispose() {
    stopPortScanning();
    _portChangeController.close();
    _killActiveProcess();
  }

  Future<void> _killActiveProcess() async {
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill();
      } catch (e) {
        _logService.addLog(
          message: 'Error killing active process: $e',
          level: LogLevel.error,
          step: ProcessStep.other,
          origin: 'arduino-cli',
        );
      }
      _activeProcess = null;
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
}
