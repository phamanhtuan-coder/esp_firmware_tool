import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;

class ArduinoCliService {
  // Define possible paths for arduino-cli
  static final List<String> possibleCliPaths = [
    'arduino-cli',
    'arduino-cli.exe',
    path.join(Directory.current.path, 'tools', 'arduino-cli.exe'),
    path.join(Directory.current.path, 'tools', 'arduino-cli'),
    'C:\\Program Files\\Arduino CLI\\arduino-cli.exe',
    'C:\\Program Files (x86)\\Arduino CLI\\arduino-cli.exe',
    path.join(Directory.current.path, 'arduino-cli.exe'),
    // Add the path where Arduino CLI was installed
    'C:\\Users\\Admin\\bin\\arduino-cli.exe',
    '/c/Users/Admin/bin/arduino-cli.exe',
    '/c/Users/Admin/bin/arduino-cli',
  ];

  String? _arduinoCliPath;
  static const String templateAssetPath = 'lib/firmware_template/led_template.ino';

  // Find the Arduino CLI executable
  Future<String> _getArduinoCliPath() async {
    if (_arduinoCliPath != null) {
      return _arduinoCliPath!;
    }

    // Try to find arduino-cli in the possible paths
    for (var cliPath in possibleCliPaths) {
      try {
        var result = await Process.run(cliPath, ['version']);
        if (result.exitCode == 0) {
          _arduinoCliPath = cliPath;
          print('Found Arduino CLI at: $cliPath');
          return cliPath;
        }
      } catch (e) {
        // Command not found, continue to next path
      }
    }

    // If CLI not found, check if we have it in assets directory
    // This would require bundling arduino-cli with your app

    // Default to hoping it's in PATH
    return 'arduino-cli';
  }

  Future<bool> isArduinoCliInstalled() async {
    try {
      var cliPath = await _getArduinoCliPath();
      var result = await Process.run(cliPath, ['version']);
      return result.exitCode == 0;
    } catch (e) {
      print('Error checking Arduino CLI: $e');
      return false;
    }
  }

  // Determine board type from sketch content
  Future<String> _getBoardType(String sketchContent) async {
    if (sketchContent.contains('ESP8266WiFi.h')) {
      return 'esp8266';
    } else if (sketchContent.contains('WiFi.h') && sketchContent.contains('ESP32')) {
      return 'esp32';
    } else {
      // Default to ESP32 if we can't determine
      return 'esp32';
    }
  }

  // Install required board package based on sketch content
  Future<void> _installBoardPackage(String arduinoCliPath, String boardType) async {
    try {
      print('Checking $boardType board package...');

      if (boardType == 'esp8266') {
        // For ESP8266, we need to configure the additional URLs first
        print('Configuring ESP8266 board URL...');

        // Try to add the ESP8266 URL without overwriting existing config
        try {
          await Process.run(
            arduinoCliPath,
            ['config', 'add', 'board_manager.additional_urls', 'https://arduino.esp8266.com/stable/package_esp8266com_index.json']
          );
        } catch (e) {
          print('Error adding board URL: $e');

          // Fallback approach: initialize config with the URL
          await Process.run(
            arduinoCliPath,
            ['config', 'init', '--additional-urls', 'https://arduino.esp8266.com/stable/package_esp8266com_index.json']
          );
        }

        // Update index to include the new URL
        print('Updating board index...');
        await Process.run(arduinoCliPath, ['core', 'update-index', '--additional-urls', 'https://arduino.esp8266.com/stable/package_esp8266com_index.json']);

        // Check if the ESP8266 board is already installed
        var listResult = await Process.run(arduinoCliPath, ['core', 'list']);
        String output = listResult.stdout.toString();

        if (!output.contains('esp8266:esp8266')) {
          print('ESP8266 board package not found. Installing...');

          // Install the ESP8266 board package
          var installResult = await Process.run(
            arduinoCliPath,
            ['core', 'install', 'esp8266:esp8266', '--additional-urls', 'https://arduino.esp8266.com/stable/package_esp8266com_index.json'],
          );

          if (installResult.exitCode != 0) {
            print('Installation stderr: ${installResult.stderr}');
            print('Installation stdout: ${installResult.stdout}');
            throw Exception('Failed to install ESP8266 board package');
          }

          print('ESP8266 board package installed successfully');
        } else {
          print('ESP8266 board package already installed');
        }
      } else {
        // For ESP32 and other boards, use the original approach
        await Process.run(arduinoCliPath, ['core', 'update-index']);

        // Check if board package is installed
        var listResult = await Process.run(arduinoCliPath, ['core', 'list']);
        String output = listResult.stdout.toString();

        if (!output.contains(boardType)) {
          print('$boardType board package not found. Installing...');

          await Process.run(
            arduinoCliPath,
            ['core', 'install', '$boardType:$boardType'],
          );

          print('$boardType board package installed successfully');
        } else {
          print('$boardType board package already installed');
        }
      }
    } catch (e) {
      print('Warning: Error during board package check: $e');
    }
  }

  // Install required libraries for the sketch
  Future<void> _installRequiredLibraries(String arduinoCliPath, String sketchContent) async {
    try {
      print('Checking and installing required libraries...');

      // Define libraries to check for and install based on sketch content
      Map<String, String> requiredLibraries = {};

      // Keep track of built-in libraries that don't need installation
      Set<String> builtInLibraries = {'Hash', 'SPI', 'Wire'};

      if (sketchContent.contains('SocketIoClient.h')) {
        // This library isn't in the standard library manager, so we need to use git
        requiredLibraries['SocketIoClient'] = 'https://github.com/timum-viw/socket.io-client.git';

        // Add dependencies for SocketIoClient
        requiredLibraries['WebSockets'] = 'https://github.com/Links2004/arduinoWebSockets.git';
        // Hash is a built-in library for ESP8266, no need to install separately
      }

      if (sketchContent.contains('ArduinoJson.h')) {
        requiredLibraries['ArduinoJson'] = 'ArduinoJson';
      }

      if (sketchContent.contains('Adafruit_NeoPixel.h')) {
        requiredLibraries['Adafruit_NeoPixel'] = 'Adafruit NeoPixel';
      }

      // Enable git-url and zip-path features in Arduino CLI configuration
      try {
        print('Enabling git-url feature in Arduino CLI...');
        await Process.run(
          arduinoCliPath,
          ['config', 'set', 'library.enable_unsafe_install', 'true']
        );
      } catch (e) {
        print('Warning: Unable to enable unsafe install: $e');
      }

      // Install each required library
      for (var entry in requiredLibraries.entries) {
        String libraryName = entry.key;

        // Skip built-in libraries
        if (builtInLibraries.contains(libraryName)) {
          print('Library $libraryName is built-in, skipping installation');
          continue;
        }

        print('Checking for library: $libraryName');

        // Check if library is already installed
        var listResult = await Process.run(arduinoCliPath, ['lib', 'list', libraryName]);
        String output = listResult.stdout.toString();

        if (!output.contains(libraryName)) {
          print('Library $libraryName not found. Installing...');

          // For git repositories
          if (entry.value.startsWith('http')) {
            print('Installing from git: ${entry.value}');
            var installResult = await Process.run(
              arduinoCliPath,
              ['lib', 'install', '--git-url', entry.value]
            );

            if (installResult.exitCode != 0) {
              print('Installation stderr: ${installResult.stderr}');
              print('Installation stdout: ${installResult.stdout}');

              // Try manual installation for SocketIoClient if git install fails
              if (entry.key == 'SocketIoClient') {
                print('Attempting manual installation of SocketIoClient...');
                await _manualInstallSocketIoClient(arduinoCliPath);
              } else {
                throw Exception('Failed to install ${entry.key} from git');
              }
            } else {
              print('Library ${entry.key} installed successfully');
            }
          }
          // For library manager libraries
          else {
            var installResult = await Process.run(
              arduinoCliPath,
              ['lib', 'install', entry.value]
            );

            if (installResult.exitCode != 0) {
              print('Installation stderr: ${installResult.stderr}');
              print('Installation stdout: ${installResult.stdout}');
              throw Exception('Failed to install ${entry.key} from library manager');
            } else {
              print('Library ${entry.key} installed successfully');
            }
          }
        } else {
          print('Library ${entry.key} already installed');
        }
      }
    } catch (e) {
      print('Warning: Error during library installation: $e');
      // Continue with compilation even if library installation fails
      // The compilation process will catch any missing libraries
    }
  }

  // Manual installation of SocketIoClient library using git clone
  Future<void> _manualInstallSocketIoClient(String arduinoCliPath) async {
    try {
      // Get Arduino libraries directory
      var result = await Process.run(arduinoCliPath, ['config', 'dump']);
      String configOutput = result.stdout.toString();

      // Extract user directory path
      RegExp userDirRegex = RegExp(r'user_dir:\s*"([^"]*)"');
      var userDirMatch = userDirRegex.firstMatch(configOutput);
      String userDir = userDirMatch?.group(1) ?? '';

      if (userDir.isEmpty) {
        // Default library location if config can't be parsed
        if (Platform.isWindows) {
          userDir = '${Platform.environment['LOCALAPPDATA'] ?? ''}\\Arduino15';
        } else {
          userDir = '${Platform.environment['HOME'] ?? ''}/.arduino15';
        }
      }

      String librariesDir = path.join(userDir, 'libraries', 'SocketIoClient');

      // Create directory if it doesn't exist
      final directory = Directory(librariesDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Use git to clone the repository
      print('Cloning SocketIoClient to $librariesDir...');
      var gitResult = await Process.run(
        'git',
        ['clone', 'https://github.com/timum-viw/socket.io-client.git', librariesDir],
      );

      if (gitResult.exitCode != 0) {
        print('Git clone stderr: ${gitResult.stderr}');
        print('Git clone stdout: ${gitResult.stdout}');
        throw Exception('Failed to git clone SocketIoClient');
      }

      print('Successfully installed SocketIoClient library manually');
    } catch (e) {
      print('Failed to manually install SocketIoClient: $e');
      throw Exception('Failed to manually install SocketIoClient: $e');
    }
  }

  Future<String> compileFirmware(String sketchPath) async {
    try {
      // First check if Arduino CLI is available
      print('Checking if Arduino CLI is installed...');
      if (!await isArduinoCliInstalled()) {
        throw Exception('Arduino CLI not installed or not found in PATH. Please install it first. '
            'Download from: https://arduino.github.io/arduino-cli/latest/installation/');
      }

      // Get the arduino-cli path
      var arduinoCliPath = await _getArduinoCliPath();
      print('Using Arduino CLI at: $arduinoCliPath');

      // Get temp directory for build
      final tempDir = await getTemporaryDirectory();
      final buildPath = '${tempDir.path}/arduino_build';

      // Create build directory if it doesn't exist
      await Directory(buildPath).create(recursive: true);

      // Create a proper Arduino sketch folder structure
      // Arduino requires sketches to be in a folder with the same name as the .ino file
      String sketchName = path.basename(sketchPath);
      if (sketchName.endsWith('.ino')) {
        sketchName = sketchName.substring(0, sketchName.length - 4);
      }

      final sketchDir = Directory('${tempDir.path}/$sketchName');
      await sketchDir.create(recursive: true);
      final sketchFile = File('${sketchDir.path}/$sketchName.ino');

      // Check if we're dealing with led_template.ino
      bool isLedTemplate = sketchPath.toLowerCase().contains('led_template.ino');

      // Determine the source of the sketch content
      String sketchContent = '';

      try {
        if (isLedTemplate) {
          // First try to read the file directly from the project directory
          final projectFile = File(path.join(Directory.current.path, 'lib/firmware_template/led_template.ino'));

          if (await projectFile.exists()) {
            print('Reading template from project directory: ${projectFile.path}');
            sketchContent = await projectFile.readAsString();
          } else {
            // If it doesn't exist, check if it's provided directly in sketchPath
            final providedFile = File(sketchPath);
            if (await providedFile.exists()) {
              print('Reading template from provided path: ${providedFile.path}');
              sketchContent = await providedFile.readAsString();
            } else {
              throw Exception('Template file not found at: ${projectFile.path} or ${providedFile.path}');
            }
          }
        } else {
          // For other sketches, just use the provided path
          final providedFile = File(sketchPath);
          if (await providedFile.exists()) {
            print('Reading sketch from provided path: ${providedFile.path}');
            sketchContent = await providedFile.readAsString();
          } else {
            throw Exception('Sketch file not found at: ${providedFile.path}');
          }
        }

        // Write the sketch content to the temporary file
        await sketchFile.writeAsString(sketchContent);
        print('Sketch created at: ${sketchFile.path}');

      } catch (e) {
        print('Error creating sketch file: $e');
        throw Exception('Failed to create sketch file: $e');
      }

      // Determine board type from sketch content
      String boardType = await _getBoardType(sketchContent);
      print('Detected board type: $boardType');

      // Install board package
      await _installBoardPackage(arduinoCliPath, boardType);

      // Install required libraries
      await _installRequiredLibraries(arduinoCliPath, sketchContent);

      // Compile the sketch from the temporary location
      print('Compiling sketch at: ${sketchFile.path}');
      print('Build path: $buildPath');

      // Set FQBN based on board type
      String fqbn = boardType == 'esp8266' ? 'esp8266:esp8266:generic' : 'esp32:esp32:esp32';

      // For ESP8266, we need to add additional URLs
      List<String> compileArgs = [
        'compile',
        '--fqbn', fqbn,
        '--build-path', buildPath,
      ];

      if (boardType == 'esp8266') {
        compileArgs.addAll(['--additional-urls', 'https://arduino.esp8266.com/stable/package_esp8266com_index.json']);
      }

      // Add the sketch path at the end
      compileArgs.add(sketchFile.path);

      // Run compilation
      var result = await Process.run(arduinoCliPath, compileArgs);

      if (result.exitCode != 0) {
        print('Compilation stderr: ${result.stderr}');
        print('Compilation stdout: ${result.stdout}');
        throw Exception('Compilation failed: ${result.stderr}');
      }

      print('Compilation successful');
      // Return path to compiled binary
      final binaryExtension = boardType == 'esp8266' ? '.ino.bin' : '.ino.bin';
      return '$buildPath/$sketchName$binaryExtension';
    } catch (e) {
      print('Compilation error: $e');
      throw Exception('Failed to compile firmware: $e');
    }
  }

  Future<void> installESP32Core() async {
    try {
      var arduinoCliPath = await _getArduinoCliPath();

      // Update index
      await Process.run(arduinoCliPath, ['core', 'update-index']);

      // Install ESP32 core
      await Process.run(
        arduinoCliPath,
        ['core', 'install', 'esp32:esp32'],
      );
    } catch (e) {
      throw Exception('Failed to install ESP32 core: $e');
    }
  }

  Future<void> installESP8266Core() async {
    try {
      var arduinoCliPath = await _getArduinoCliPath();

      // Update index
      await Process.run(
        arduinoCliPath,
        ['config', 'init', '--additional-urls', 'https://arduino.esp8266.com/stable/package_esp8266com_index.json']
      );

      // Install ESP8266 core
      await Process.run(
        arduinoCliPath,
        [
          'core', 'install', 'esp8266:esp8266',
          '--additional-urls', 'https://arduino.esp8266.com/stable/package_esp8266com_index.json'
        ],
      );
    } catch (e) {
      throw Exception('Failed to install ESP8266 core: $e');
    }
  }
}