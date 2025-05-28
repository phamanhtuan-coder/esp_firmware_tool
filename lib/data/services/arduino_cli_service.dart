import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ArduinoCliService {
  static const String arduinoCliCmd = 'arduino-cli';

  Future<bool> isArduinoCliInstalled() async {
    try {
      var result = await Process.run(arduinoCliCmd, ['version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<String> compileFirmware(String sketchPath) async {
    try {
      // Get temp directory for build
      final tempDir = await getTemporaryDirectory();
      final buildPath = '${tempDir.path}/arduino_build';

      // Create build directory if it doesn't exist
      await Directory(buildPath).create(recursive: true);

      // Compile sketch
      var result = await Process.run(
        arduinoCliCmd,
        [
          'compile',
          '--fqbn', 'esp32:esp32:esp32', // For ESP32
          '--build-path', buildPath,
          sketchPath,
        ],
      );

      if (result.exitCode != 0) {
        throw Exception('Compilation failed: ${result.stderr}');
      }

      // Return path to compiled binary
      return '$buildPath/${sketchPath.split('/').last}.ino.bin';
    } catch (e) {
      throw Exception('Failed to compile firmware: $e');
    }
  }

  Future<void> installESP32Core() async {
    try {
      // Update index
      await Process.run(arduinoCliCmd, ['core', 'update-index']);

      // Install ESP32 core
      await Process.run(
        arduinoCliCmd,
        ['core', 'install', 'esp32:esp32'],
      );
    } catch (e) {
      throw Exception('Failed to install ESP32 core: $e');
    }
  }
}