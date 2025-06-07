import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/template_service.dart';
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
      _logService.addLog(
        message: 'Initializing Arduino CLI service...',
        level: LogLevel.info,
        step: ProcessStep.systemStart,
        origin: 'arduino-cli',
      );

      if (_arduinoCliPath != null) {
        _logService.addLog(
          message: 'Arduino CLI already initialized at: $_arduinoCliPath',
          level: LogLevel.info,
          step: ProcessStep.systemStart,
          origin: 'arduino-cli',
        );
        return await _verifyArduinoCli();
      }

      final appDir = await getApplicationDocumentsDirectory();
      String appName = Platform.isWindows
          ? 'arduino-cli'
          : Platform.isMacOS
              ? 'arduino-cli-macos'
              : 'arduino-cli-linux';
      String executableName = Platform.isWindows ? 'arduino-cli.exe' : 'arduino-cli';

      _logService.addLog(
        message: 'Setting up Arduino CLI for platform: $appName',
        level: LogLevel.info,
        step: ProcessStep.systemStart,
        origin: 'arduino-cli',
      );

      final arduinoDir = Directory(path.join(appDir.path, appName));
      if (!await arduinoDir.exists()) {
        await arduinoDir.create(recursive: true);
        _logService.addLog(
          message: 'Created Arduino CLI directory at: ${arduinoDir.path}',
          level: LogLevel.info,
          step: ProcessStep.systemStart,
          origin: 'arduino-cli',
        );
      }

      _arduinoCliPath = path.join(arduinoDir.path, executableName);
      final cliFile = File(_arduinoCliPath!);

      if (!await cliFile.exists()) {
        _logService.addLog(
          message: 'Arduino CLI not found, extracting from assets...',
          level: LogLevel.info,
          step: ProcessStep.systemStart,
          origin: 'arduino-cli',
        );

        try {
          final byteData = await rootBundle.load('assets/$appName/$executableName');
          final buffer = byteData.buffer;
          await cliFile.writeAsBytes(
            buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          );

          if (!Platform.isWindows) {
            await Process.run('chmod', ['+x', _arduinoCliPath!]);
          }

          _logService.addLog(
            message: 'Arduino CLI extracted successfully',
            level: LogLevel.success,
            step: ProcessStep.systemStart,
            origin: 'arduino-cli',
          );
        } catch (e) {
          _logService.addLog(
            message: 'Failed to extract Arduino CLI: $e',
            level: LogLevel.error,
            step: ProcessStep.systemStart,
            origin: 'arduino-cli',
          );
          return false;
        }
      }

      // Verify CLI works and print version
      if (!await _verifyArduinoCli()) {
        return false;
      }

      // Initialize config file if needed
      if (!await _initializeConfig()) {
        return false;
      }

      // Update package index
      _logService.addLog(
        message: 'Updating Arduino CLI package index...',
        level: LogLevel.info,
        step: ProcessStep.systemStart,
        origin: 'arduino-cli',
      );

      final updateResult = await Process.run(_arduinoCliPath!, ['core', 'update-index', '--verbose']);
      if (updateResult.exitCode != 0) {
        _logService.addLog(
          message: 'Failed to update package index: ${updateResult.stderr}',
          level: LogLevel.error,
          step: ProcessStep.systemStart,
          origin: 'arduino-cli',
        );
        return false;
      }

      // Install required cores
      for (final type in _boardFqbns.keys) {
        final core = _getCoreForDeviceType(type);
        if (core != null) {
          _logService.addLog(
            message: 'Installing core for $type: $core',
            level: LogLevel.info,
            step: ProcessStep.systemStart,
            origin: 'arduino-cli',
          );

          final installResult = await Process.run(_arduinoCliPath!, [
            'core',
            'install',
            core,
            '--verbose'
          ]);

          if (installResult.exitCode != 0) {
            _logService.addLog(
              message: 'Failed to install core $core: ${installResult.stderr}',
              level: LogLevel.error,
              step: ProcessStep.systemStart,
              origin: 'arduino-cli',
            );
          } else {
            _logService.addLog(
              message: 'Successfully installed core $core',
              level: LogLevel.success,
              step: ProcessStep.systemStart,
              origin: 'arduino-cli',
            );
          }
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

  Future<bool> _verifyArduinoCli() async {
    try {
      final result = await Process.run(_arduinoCliPath!, ['version', '--verbose']);

      if (result.exitCode != 0) {
        _logService.addLog(
          message: 'Arduino CLI verification failed: ${result.stderr}',
          level: LogLevel.error,
          step: ProcessStep.systemStart,
          origin: 'arduino-cli',
        );
        return false;
      }

      _logService.addLog(
        message: 'Arduino CLI verified: ${result.stdout}',
        level: LogLevel.success,
        step: ProcessStep.systemStart,
        origin: 'arduino-cli',
      );
      return true;
    } catch (e) {
      _logService.addLog(
        message: 'Error verifying Arduino CLI: $e',
        level: LogLevel.error,
        step: ProcessStep.systemStart,
        origin: 'arduino-cli',
      );
      return false;
    }
  }

  Future<bool> _initializeConfig() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configDir = Directory(path.join(appDir.path, 'arduino-cli'));
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      final configPath = path.join(configDir.path, 'arduino-cli.yaml');
      if (!await File(configPath).exists()) {
        final initResult = await Process.run(_arduinoCliPath!, [
          'config',
          'init',
          '--dest-dir',
          configDir.path,
          '--verbose'
        ]);

        if (initResult.exitCode != 0) {
          _logService.addLog(
            message: 'Failed to initialize config: ${initResult.stderr}',
            level: LogLevel.error,
            step: ProcessStep.systemStart,
            origin: 'arduino-cli',
          );
          return false;
        }

        _logService.addLog(
          message: 'Arduino CLI config initialized at: $configPath',
          level: LogLevel.success,
          step: ProcessStep.systemStart,
          origin: 'arduino-cli',
        );
      }
      return true;
    } catch (e) {
      _logService.addLog(
        message: 'Error initializing config: $e',
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
        message: 'Starting compilation for sketch: $sketchPath with FQBN: $fqbn',
        level: LogLevel.info,
        step: ProcessStep.firmwareCompile,
        origin: 'arduino-cli',
      );

      // Log các cổng COM hiện có
      final availablePorts = SerialPort.availablePorts;
      _logService.addLog(
        message: 'Available COM ports before compilation: ${availablePorts.join(", ")}',
        level: LogLevel.info,
        step: ProcessStep.firmwareCompile,
        origin: 'arduino-cli',
      );

      await _killActiveProcess();

      // Log đường dẫn Arduino CLI
      _logService.addLog(
        message: 'Arduino CLI path: $_arduinoCliPath',
        level: LogLevel.debug,
        step: ProcessStep.firmwareCompile,
        origin: 'arduino-cli',
      );

      // Ensure CLI is initialized
      if (_arduinoCliPath == null || !await File(_arduinoCliPath!).exists()) {
        throw Exception('Arduino CLI not initialized or missing');
      }

      // First verify board core is installed
      final boardCore = fqbn.split(':').take(2).join(':');
      final coreResult = await Process.run(_arduinoCliPath!, [
        'core',
        'list',
        '--format=json'
      ]);

      _logService.addLog(
        message: 'Core list result: ${coreResult.stdout}',
        level: LogLevel.debug,
        step: ProcessStep.firmwareCompile,
        origin: 'arduino-cli',
      );

      if (!coreResult.stdout.toString().contains(boardCore)) {
        _logService.addLog(
          message: 'Installing required board core: $boardCore',
          level: LogLevel.info,
          step: ProcessStep.firmwareCompile,
          origin: 'arduino-cli',
        );

        final installResult = await Process.run(_arduinoCliPath!, [
          'core',
          'install',
          boardCore,
          '--verbose'
        ]);

        if (installResult.exitCode != 0) {
          _logService.addLog(
            message: 'Core installation output: ${installResult.stdout}\nError: ${installResult.stderr}',
            level: LogLevel.error,
            step: ProcessStep.firmwareCompile,
            origin: 'arduino-cli',
          );
          throw Exception('Failed to install board core: ${installResult.stderr}');
        }
      }

      // Verify sketch file exists
      if (!await File(sketchPath).exists()) {
        throw Exception('Sketch file not found: $sketchPath');
      }

      // Log sketch content for debugging
      final sketchContent = await File(sketchPath).readAsString();
      _logService.addLog(
        message: 'Sketch content:\n$sketchContent',
        level: LogLevel.debug,
        step: ProcessStep.firmwareCompile,
        origin: 'arduino-cli',
      );

      // Now compile with verbose output
      _logService.addLog(
        message: 'Starting compilation with command: $_arduinoCliPath compile --fqbn $fqbn --verbose $sketchPath',
        level: LogLevel.debug,
        step: ProcessStep.firmwareCompile,
        origin: 'arduino-cli',
      );

      _activeProcess = await Process.start(_arduinoCliPath!, [
        'compile',
        '--fqbn', fqbn,
        '--verbose',
        sketchPath,
      ]);

      final stdoutCompleter = Completer<String>();
      final stderrCompleter = Completer<String>();
      final stdout = StringBuffer();
      final stderr = StringBuffer();

      // Capture stdout with enhanced parsing
      final stdoutSubscription = _activeProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            stdout.write('$line\n');
            _logService.addLog(
              message: line.trim(),
              level: _getLogLevelFromOutput(line),
              step: ProcessStep.firmwareCompile,
              origin: 'arduino-cli',
              rawOutput: line,
            );

            // Log specific compilation events
            if (line.contains('Detecting libraries used')) {
              _logService.addLog(
                message: 'Detecting required libraries...',
                level: LogLevel.info,
                step: ProcessStep.firmwareCompile,
                origin: 'arduino-cli',
              );
            } else if (line.contains('Starting compilation')) {
              _logService.addLog(
                message: 'Starting compilation process...',
                level: LogLevel.info,
                step: ProcessStep.firmwareCompile,
                origin: 'arduino-cli',
              );
            } else if (line.contains('Compiling sketch...')) {
              _logService.addLog(
                message: 'Compiling sketch...',
                level: LogLevel.info,
                step: ProcessStep.firmwareCompile,
                origin: 'arduino-cli',
              );
            } else if (line.contains('Sketch uses')) {
              _logService.addLog(
                message: line.trim(),
                level: LogLevel.info,
                step: ProcessStep.firmwareCompile,
                origin: 'arduino-cli',
              );
            }
          },
          onDone: () => stdoutCompleter.complete(stdout.toString()),
          cancelOnError: true,
        );

      // Capture stderr with enhanced error parsing
      final stderrSubscription = _activeProcess!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            stderr.write('$line\n');
            // Parse error messages more carefully
            if (line.contains('error:') || line.contains('Error:')) {
              _logService.addLog(
                message: 'Compilation Error: ${line.trim()}',
                level: LogLevel.error,
                step: ProcessStep.firmwareCompile,
                origin: 'arduino-cli',
                rawOutput: line,
              );
            } else if (line.contains('warning:')) {
              _logService.addLog(
                message: 'Compilation Warning: ${line.trim()}',
                level: LogLevel.warning,
                step: ProcessStep.firmwareCompile,
                origin: 'arduino-cli',
                rawOutput: line,
              );
            } else {
              _logService.addLog(
                message: line.trim(),
                level: LogLevel.error,
                step: ProcessStep.firmwareCompile,
                origin: 'arduino-cli',
                rawOutput: line,
              );
            }
          },
          onDone: () => stderrCompleter.complete(stderr.toString()),
          cancelOnError: true,
        );

      // Wait for process to complete and output to be fully captured
      final exitCode = await _activeProcess!.exitCode;
      final stdoutStr = await stdoutCompleter.future;
      final stderrStr = await stderrCompleter.future;

      // Clean up subscriptions
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      _activeProcess = null;

      _logService.addLog(
        message: 'Compilation process completed with exit code: $exitCode',
        level: LogLevel.debug,
        step: ProcessStep.firmwareCompile,
        origin: 'arduino-cli',
      );

      if (exitCode == 0) {
        _logService.addLog(
          message: 'Compilation successful\nOutput: $stdoutStr',
          level: LogLevel.success,
          step: ProcessStep.firmwareCompile,
          origin: 'arduino-cli',
        );
        return true;
      } else {
        // Enhanced error reporting
        final errorOutput = stderrStr.trim();
        final error = errorOutput.isNotEmpty
          ? 'Compilation failed: $errorOutput\nStdout: $stdoutStr'
          : 'Compilation failed with exit code $exitCode\nFull output:\n$stdoutStr';

        _logService.addLog(
          message: error,
          level: LogLevel.error,
          step: ProcessStep.firmwareCompile,
          origin: 'arduino-cli',
        );

        throw Exception(error);
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
      _logService.addLog(
        message: 'Starting upload to port $port with FQBN: $fqbn',
        level: LogLevel.info,
        step: ProcessStep.flash,
        origin: 'arduino-cli',
      );

      // Log các cổng COM hiện có
      final availablePorts = SerialPort.availablePorts;
      _logService.addLog(
        message: 'Available COM ports before upload: ${availablePorts.join(", ")}',
        level: LogLevel.info,
        step: ProcessStep.flash,
        origin: 'arduino-cli',
      );

      // Kiểm tra xem cổng đã chọn có tồn tại không
      if (!availablePorts.contains(port)) {
        _logService.addLog(
          message: 'Selected port $port not found in available ports',
          level: LogLevel.error,
          step: ProcessStep.flash,
          origin: 'arduino-cli',
        );
        throw Exception('Selected COM port not found');
      }

      // Ensure CLI is initialized
      if (_arduinoCliPath == null || !await File(_arduinoCliPath!).exists()) {
        throw Exception('Arduino CLI not initialized or missing');
      }

      if (!await _validatePortAccess(port)) {
        throw Exception('Cannot access port $port. Check if another program is using it.');
      }

      await _killActiveProcess();

      // On Windows, try to reset the port
      if (Platform.isWindows) {
        try {
          await Process.run('mode', [port]);
          await Future.delayed(const Duration(milliseconds: 500));

          // Additional step to ensure port is released
          await Process.run('net', ['stop', 'SerialPort']);
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          _logService.addLog(
            message: 'Warning: Port reset attempted but failed: $e',
            level: LogLevel.warning,
            step: ProcessStep.flash,
            origin: 'arduino-cli',
          );
          // Continue anyway as this is just a precautionary step
        }
      }

      // Upload with verbose output
      _activeProcess = await Process.start(_arduinoCliPath!, [
        'upload',
        '-p', port,
        '--fqbn', fqbn,
        '--verbose',
        sketchPath,
      ]);

      final stdoutCompleter = Completer<String>();
      final stderrCompleter = Completer<String>();
      final stdout = StringBuffer();
      final stderr = StringBuffer();

      // Capture stdout
      final stdoutSubscription = _activeProcess!.stdout
        .transform(utf8.decoder)
        .listen(
          (data) {
            stdout.write(data);
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
          },
          onDone: () => stdoutCompleter.complete(stdout.toString()),
          cancelOnError: true,
        );

      // Capture stderr
      final stderrSubscription = _activeProcess!.stderr
        .transform(utf8.decoder)
        .listen(
          (data) {
            stderr.write(data);
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
          },
          onDone: () => stderrCompleter.complete(stderr.toString()),
          cancelOnError: true,
        );

      // Wait for process to complete and output to be fully captured
      final exitCode = await _activeProcess!.exitCode;
      final stdoutStr = await stdoutCompleter.future;
      final stderrStr = await stderrCompleter.future;

      // Clean up subscriptions
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
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
        final errorOutput = stderrStr.trim();
        final error = errorOutput.isNotEmpty
          ? 'Upload failed: $errorOutput'
          : 'Upload failed with exit code $exitCode\nOutput: $stdoutStr';

        throw Exception(error);
      }
    } catch (e) {
      final errorMessage = e.toString();
      _logService.addLog(
        message: 'Error during upload: $errorMessage',
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
    String? deviceType,
    String? batchId,
    Map<String, String>? placeholders,
  }) async {
    try {
      print('DEBUG: Starting compile and flash process');
      print('DEBUG: Device type detected: $deviceType');

      // If no device type specified, try to detect from sketch content
      if (deviceType == null || deviceType.isEmpty) {
        final sketchContent = await File(sketchPath).readAsString();
        deviceType = GetIt.instance<TemplateService>().extractBoardType(sketchContent);
        print('DEBUG: Device type extracted from sketch: $deviceType');
      }

      // Normalize the device type to match our FQBN mapping
      deviceType = GetIt.instance<TemplateService>().normalizeDeviceType(deviceType!);
      print('DEBUG: Normalized device type: $deviceType');

      // Get FQBN for the device type
      final fqbn = _boardFqbns[deviceType];
      if (fqbn == null) {
        throw Exception('Unsupported board type: $deviceType');
      }
      print('DEBUG: Using FQBN: $fqbn');

      // First verify Arduino CLI is accessible
      if (_arduinoCliPath == null || !await File(_arduinoCliPath!).exists()) {
        throw Exception('Arduino CLI not initialized or missing');
      }

      // Verify Arduino CLI binary can be executed
      try {
        final testResult = await Process.run(_arduinoCliPath!, ['version']);
        print('DEBUG: Arduino CLI test result: ${testResult.exitCode}');
        print('DEBUG: Arduino CLI stdout: ${testResult.stdout}');
        print('DEBUG: Arduino CLI stderr: ${testResult.stderr}');

        if (testResult.exitCode != 0) {
          throw Exception('Arduino CLI cannot be executed: ${testResult.stderr}');
        }
      } catch (e) {
        print('DEBUG: Failed to execute Arduino CLI: $e');
        throw Exception('Arduino CLI execution failed: $e');
      }

      // Install required core if needed
      final boardCore = fqbn.split(':').take(2).join(':');
      final coreResult = await Process.run(_arduinoCliPath!, ['core', 'list']);
      if (!coreResult.stdout.toString().contains(boardCore)) {
        print('DEBUG: Installing required board core: $boardCore');
        final installResult = await Process.run(_arduinoCliPath!, ['core', 'install', boardCore]);
        if (installResult.exitCode != 0) {
          throw Exception('Failed to install board core: ${installResult.stderr}');
        }
      }

      // Then run direct command for compiling to see direct output
      print('DEBUG: Starting direct compilation...');
      final directCompileResult = await Process.run(_arduinoCliPath!, [
        'compile',
        '--fqbn', fqbn,
        '--verbose',
        sketchPath,
      ]);

      // Log direct output from the process
      print('DEBUG: Compile exit code: ${directCompileResult.exitCode}');
      print('DEBUG: Compile stdout: ${directCompileResult.stdout}');
      print('DEBUG: Compile stderr: ${directCompileResult.stderr}');

      // If direct compile fails, stop here
      if (directCompileResult.exitCode != 0) {
        throw Exception('Direct compilation failed: ${directCompileResult.stderr}\n${directCompileResult.stdout}');
      }

      // If compile succeeded, try uploading directly
      print('DEBUG: Starting direct upload...');
      final directUploadResult = await Process.run(_arduinoCliPath!, [
        'upload',
        '-p', port,
        '--fqbn', fqbn,
        '--verbose',
        sketchPath,
      ]);

      // Log direct output from upload process
      print('DEBUG: Upload exit code: ${directUploadResult.exitCode}');
      print('DEBUG: Upload stdout: ${directUploadResult.stdout}');
      print('DEBUG: Upload stderr: ${directUploadResult.stderr}');

      if (directUploadResult.exitCode != 0) {
        throw Exception('Direct upload failed: ${directUploadResult.stderr}');
      }

      print('DEBUG: Direct compile and upload successful!');

      // Log success
      _logService.addLog(
        message: 'Firmware compiled and uploaded successfully',
        level: LogLevel.success,
        step: ProcessStep.flash,
        deviceId: deviceId,
        origin: 'arduino-cli',
      );

      print('DEBUG: Compile and flash completed successfully');
      return true;
    } catch (e) {
      print('DEBUG: Error in compileAndFlash: $e');
      _logService.addLog(
        message: 'Error during compile and flash: $e',
        level: LogLevel.error,
        step: ProcessStep.flash,
        deviceId: deviceId,
        origin: 'arduino-cli',
      );
      return false;
    }
  }

  Future<String?> prepareFirmwareTemplate(
    String sourcePath,
    String serialNumber,
    String deviceId, {
    Map<String, String>? placeholders,
  }) async {
    try {
      // If sourcePath contains firmware content instead of a path, save it to temp file first
      if (sourcePath.trim().startsWith('//') || sourcePath.trim().startsWith('#')) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(path.join(tempDir.path, 'firmware_${DateTime.now().millisecondsSinceEpoch}.ino'));
        await tempFile.writeAsString(sourcePath);
        sourcePath = tempFile.path;
      }

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

    // Kiểm tra các lỗi
    if (lower.contains('error') ||
        lower.contains('failed') ||
        lower.contains('cannot access') ||
        lower.contains('not found') ||
        lower.contains('denied')) {
      return LogLevel.error;
    }

    // Kiểm tra warnings
    if (lower.contains('warning')) {
      return LogLevel.warning;
    }

    // Kiểm tra thành công
    if (lower.contains('success') ||
        lower.contains('done') ||
        lower.contains('uploaded') ||
        lower.contains('complete') ||
        (lower.contains('bytes') && lower.contains('written'))) {
      return LogLevel.success;
    }

    // Kiểm tra thông tin chi tiết
    if (lower.contains('avrdude:') ||
        lower.contains('compiling') ||
        lower.contains('writing') ||
        lower.contains('reading') ||
        lower.contains('sketch uses') ||
        lower.contains('maximum is') ||
        lower.contains('global variables use')) {
      return LogLevel.verbose;
    }

    return LogLevel.info;
  }

  void _logProcessOutput(String output, LogLevel level, ProcessStep step, String deviceId) {
    if (output.trim().isEmpty) return;

    final lines = output.split('\n');
    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      _logService.addLog(
        message: line.trim(),
        level: _getLogLevelFromOutput(line),
        step: step,
        deviceId: deviceId,
        origin: 'arduino-cli',
        rawOutput: line,
      );
    }
  }

  String _formatSize(String output) {
    // Định dạng thông tin kích thước sketch để dễ đọc hơn
    final sketchMatch = RegExp(r'Sketch uses (\d+) bytes.*Maximum is (\d+)').firstMatch(output);
    if (sketchMatch != null) {
      final used = int.parse(sketchMatch.group(1)!);
      final total = int.parse(sketchMatch.group(2)!);
      final percent = (used / total * 100).toStringAsFixed(1);
      return '📊 Sketch sử dụng $used bytes ($percent%) trên tổng $total bytes';
    }
    return output;
  }
}
