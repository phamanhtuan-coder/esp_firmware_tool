import 'dart:collection';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart'; // Thêm để tính hash
import 'dart:convert';

import '../models/log_entry.dart';
import 'log_service.dart';

/// Service for managing firmware templates
class TemplateService {
  final LogService _logService;
  String? _templatesDir;

  TemplateService({required LogService logService}) : _logService = logService {
    _initTemplatesDir();
  }

  Future<void> _initTemplatesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    _templatesDir = path.join(appDir.path, 'firmware_templates');
    final dir = Directory(_templatesDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Normalize board type to a standard format
  String normalizeDeviceType(String deviceType) {
    // Convert to lowercase for consistency
    final type = deviceType.toLowerCase();

    // Mapping of variant names to standard names
    final Map<String, String> boardAliases = {
      'arduino_uno_r3': 'arduino_uno',
      'uno': 'arduino_uno',
      'mega': 'arduino_mega',
      'nano': 'arduino_nano',
    };

    return boardAliases[type] ?? type;
  }

  /// Extract board type from template file content
  String extractBoardType(String content) {
    // Default to ESP32 if we can't determine
    String boardType = 'esp32';

    // First, look for a board type marked as ACTIVE in comments
    final activeCommentPattern = RegExp(r'\/\/\s*BOARD_TYPE:\s*(\w+)\s*\(ACTIVE\)', multiLine: true);
    final activeMatches = activeCommentPattern.allMatches(content);

    if (activeMatches.isNotEmpty) {
      final foundType = activeMatches.first.group(1)?.toLowerCase();
      if (foundType != null) {
        boardType = normalizeDeviceType(foundType);
        print('DEBUG: Found board type marked as ACTIVE: $boardType');
        return boardType;
      }
    }

    // Look for any BOARD_TYPE directive (active or commented)
    final boardTypePattern = RegExp(r'(?:\/\/\s*)?BOARD_TYPE:\s*(\w+)', multiLine: true);
    final matches = boardTypePattern.allMatches(content);

    if (matches.isNotEmpty) {
      // If we find an uncommented BOARD_TYPE, use that
      for (final match in matches) {
        final line = match.group(0);
        if (line != null && !line.trim().startsWith('//')) {
          final foundType = match.group(1)?.toLowerCase();
          if (foundType != null) {
            boardType = normalizeDeviceType(foundType);
            print('DEBUG: Found active board type: $boardType');
            break;
          }
        }
      }
    }

    // If no active board type found, log all found types for debugging
    if (boardType == 'esp32') {
      print('DEBUG: No active board type found, all found types:');
      for (final match in matches) {
        print('DEBUG: - ${match.group(1)}');
      }
    }

    return boardType;
  }

  Future<String?> prepareFirmwareTemplate(
      String templatePath,
      String serialNumber,
      String deviceId, {
      bool useQuotesForDefines = true,
      }) async {
    try {
      print('DEBUG: Starting template preparation');
      print('DEBUG: Template path: $templatePath');
      print('DEBUG: Serial number: $serialNumber');
      print('DEBUG: Device ID: $deviceId');

      _logService.addLog(
        message: 'Starting template preparation for $serialNumber',
        level: LogLevel.info,
        step: ProcessStep.templatePreparation,
        deviceId: serialNumber,
        origin: 'system',
      );

      if (serialNumber.isEmpty) {
        throw Exception('Serial number cannot be empty');
      }

      // Validate template file
      final templateFile = File(templatePath);
      print('DEBUG: Checking template file existence');
      if (!await templateFile.exists()) {
        throw Exception('Template file not found: $templatePath');
      }
      print('DEBUG: Template file exists');

      // Read template content
      print('DEBUG: Reading template content');
      String content = await templateFile.readAsString();
      print('DEBUG: Template content length: ${content.length}');

      // Get temporary directory for processed template
      print('DEBUG: Creating temp directory');
      final tempDir = await getTemporaryDirectory();
      final sketchName = 'firmware_${serialNumber}_${DateTime.now().millisecondsSinceEpoch}';
      final sketchDir = Directory(path.join(tempDir.path, sketchName));
      await sketchDir.create(recursive: true);
      print('DEBUG: Temp directory created at: ${sketchDir.path}');

      // Process template with replacements
      print('DEBUG: Processing replacements');
      final replacements = {
        'SERIAL_NUMBER': serialNumber,
        'serial_number': serialNumber.toLowerCase(),
        'SerialNumber': serialNumber,
        'DEVICE_ID': deviceId,
        'device_id': deviceId.toLowerCase(),
        'DeviceId': deviceId,
        'DEVICE_UUID': serialNumber,
        'device_uuid': serialNumber.toLowerCase(),
        'DeviceUuid': serialNumber,
        'AP_SSID': 'AP_$serialNumber',
        'ap_ssid': 'ap_${serialNumber.toLowerCase()}',
        'ApSsid': 'AP_$serialNumber',
      };

      // Process special defines
      content = _processDefines(content, serialNumber, deviceId);
      print('DEBUG: Defines processed');

      // Process remaining placeholders
      for (final entry in replacements.entries) {
        final placeholder = '{{${entry.key}}}';
        if (content.contains(placeholder)) {
          content = content.replaceAll(placeholder, entry.value);
          print('DEBUG: Replaced $placeholder with ${entry.value}');
        }
      }

      // Extract and validate board type
      final boardType = extractBoardType(content);
      print('DEBUG: Detected board type: $boardType');

      // Write processed content
      final outputPath = path.join(sketchDir.path, '$sketchName.ino');
      print('DEBUG: Writing processed content to: $outputPath');
      await File(outputPath).writeAsString(content);

      // Save metadata
      await _saveBoardTypeMetadata(sketchDir.path, boardType);

      print('DEBUG: Template preparation completed successfully');
      _logService.addLog(
        message: 'Template prepared successfully at: $outputPath',
        level: LogLevel.success,
        step: ProcessStep.templatePreparation,
        deviceId: serialNumber,
        origin: 'system',
      );

      return outputPath;
    } catch (e, stack) {
      print('DEBUG: Error in prepareFirmwareTemplate:');
      print('Error: $e');
      print('Stack trace: $stack');

      _logService.addLog(
        message: 'Error preparing template: $e\n$stack',
        level: LogLevel.error,
        step: ProcessStep.templatePreparation,
        deviceId: serialNumber,
        origin: 'system',
      );
      return null;
    }
  }

  /// Save board type metadata in a file next to the sketch
  Future<void> _saveBoardTypeMetadata(String sketchDir, String boardType) async {
    try {
      final metadataFile = File(path.join(sketchDir, 'board_metadata.json'));
      final metadata = {
        'boardType': boardType,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await metadataFile.writeAsString(json.encode(metadata));
      print('DEBUG: Saved board metadata: $boardType');
    } catch (e) {
      print('DEBUG: Failed to save board metadata: $e');
    }
  }

  /// Update board type directives in the template file
  String _updateBoardTypeDirectives(String content, String selectedBoardType) {
    // Find all board type directives
    final boardTypeRegex = RegExp(r'(\/\/\s*)?BOARD_TYPE:\s*(\w+)', multiLine: true);

    // First, make sure all directives are commented
    content = content.replaceAllMapped(boardTypeRegex, (match) {
      final boardType = match.group(2)?.toLowerCase() ?? '';
      return '// BOARD_TYPE: $boardType';
    });

    // Now add a special comment that Arduino CLI can use but won't be treated as code
    content = content.replaceAll(
      '// BOARD_TYPE: ${selectedBoardType.toLowerCase()}',
      '// BOARD_TYPE: ${selectedBoardType.toLowerCase()} (ACTIVE)'
    );

    print('DEBUG: Set ${selectedBoardType.toLowerCase()} as active board type');
    return content;
  }

  String _processDefines(String content, String serialNumber, String deviceId, {bool useQuotesForDefines = true}) {
    // Clean up serial number and device ID - remove any duplicates
    serialNumber = _cleanupIdentifier(serialNumber);
    deviceId = _cleanupIdentifier(deviceId);

    // Check if the defines already exist in the content
    bool hasSerialNumberDefine = content.contains('#define SERIAL_NUMBER') ||
                                content.contains('#define serial_number');
    bool hasDeviceIdDefine = content.contains('#define DEVICE_ID') ||
                            content.contains('#define device_id');

    // Replace template placeholders first
    content = content.replaceAll('{{SERIAL_NUMBER}}', serialNumber);
    content = content.replaceAll('{{DEVICE_ID}}', deviceId);

    // Define patterns for quoted and unquoted defines
    final definePlaceholderPattern = RegExp(r'#define\s+(SERIAL_NUMBER|DEVICE_ID)\s+"(\{\{[A-Z_]+\}\})"');
    final defineQuotePattern = RegExp(r'#define\s+(SERIAL_NUMBER|DEVICE_ID)\s+"([^"\n\r]*)"');
    final defineUnquotePattern = RegExp(r'#define\s+(SERIAL_NUMBER|DEVICE_ID)\s+([^"\n\r]*)');

    // Replace placeholder defines with actual values
    content = content.replaceAllMapped(definePlaceholderPattern, (match) {
      final defineName = match.group(1)!;
      final value = defineName == 'SERIAL_NUMBER' ? serialNumber : deviceId;
      return '#define $defineName "$value"';
    });

    // Replace quoted defines
    content = content.replaceAllMapped(defineQuotePattern, (match) {
      final defineName = match.group(1)!;
      final value = defineName == 'SERIAL_NUMBER' ? serialNumber : deviceId;
      return '#define $defineName "$value"';
    });

    // Replace unquoted defines
    content = content.replaceAllMapped(defineUnquotePattern, (match) {
      final defineName = match.group(1)!;
      final value = defineName == 'SERIAL_NUMBER' ? serialNumber : deviceId;
      return '#define $defineName "$value"';
    });

    // If defines don't exist, add them at the beginning of the file
    if (!hasSerialNumberDefine) {
      content = '#define SERIAL_NUMBER "$serialNumber"\n$content';
    }

    if (!hasDeviceIdDefine) {
      content = '#define DEVICE_ID "$deviceId"\n $content';
    }

    return content;
  }

  // Helper method to clean up identifiers by removing duplicates
  String _cleanupIdentifier(String identifier) {
    // Remove any non-alphanumeric characters and split
    final parts = identifier.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ').split(' ');
    // Filter out empty parts and duplicates while preserving order
    return LinkedHashSet<String>.from(parts.where((p) => p.isNotEmpty)).join('');
  }

  Future<String?> saveFirmwareTemplate(
      String sourceCode,
      String firmwareVersion,
      String deviceType, {
        String? expectedHash,
      }) async {
    try {
      if (_templatesDir == null) {
        await _initTemplatesDir();
      }

      // Follow exact same structure as _getLocalTemplatePath
      final deviceTemplateDir = path.join(_templatesDir!, '${deviceType}_template');
      final firmwareFolderName = firmwareVersion.replaceAll('.', '_');
      final firmwareFolderPath = path.join(deviceTemplateDir, firmwareFolderName);
      final fileName = '$firmwareFolderName.ino';
      final filePath = path.join(firmwareFolderPath, fileName);

      // Create the device template directory first
      final deviceDir = Directory(deviceTemplateDir);
      if (!await deviceDir.exists()) {
        await deviceDir.create(recursive: true);
      }

      // Create firmware version directory
      final firmwareDir = Directory(firmwareFolderPath);
      if (!await firmwareDir.exists()) {
        await firmwareDir.create(recursive: true);
      }

      // Validate hash if provided
      if (expectedHash != null) {
        final contentHash = md5.convert(utf8.encode(sourceCode)).toString();
        print('DEBUG: Content hash: $contentHash');
        print('DEBUG: Expected hash: $expectedHash');

        if (contentHash != expectedHash) {
          _logService.addLog(
            message: 'Hash mismatch for firmware $firmwareVersion',
            level: LogLevel.error,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
          );
          return null;
        }
      }

      // Save the firmware file
      final file = File(filePath);
      await file.writeAsString(sourceCode);
      print('DEBUG: Source code written to file: $filePath');

      // Save metadata in the same directory structure
      await _saveMetadata(firmwareVersion, deviceType, filePath);
      print('DEBUG: Metadata saved');

      _logService.addLog(
        message: 'Firmware template saved successfully',
        level: LogLevel.success,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );

      return filePath;
    } catch (e, stackTrace) {
      print('DEBUG: Error in saveFirmwareTemplate:');
      print('Error: $e');
      print('Stack trace: $stackTrace');

      _logService.addLog(
        message: 'Error saving template: $e\n$stackTrace',
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );
      return null;
    }
  }

  Future<void> _saveMetadata(String firmwareVersion, String deviceType, String filePath) async {
    try {
      // Use the same directory structure as the template
      final deviceTemplateDir = path.join(_templatesDir!, '${deviceType}_template');
      final firmwareFolderName = firmwareVersion.replaceAll('.', '_');
      final metadataDir = path.join(deviceTemplateDir, firmwareFolderName, 'metadata');

      // Create metadata directory if it doesn't exist
      await Directory(metadataDir).create(recursive: true);

      // Save metadata file in the same folder as the firmware
      final metadataFile = File(path.join(metadataDir, 'template_info.json'));
      final metadata = {
        'version': firmwareVersion,
        'deviceType': deviceType,
        'filePath': filePath,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await metadataFile.writeAsString(json.encode(metadata));
      print('DEBUG: Metadata saved to: ${metadataFile.path}');
    } catch (e) {
      print('DEBUG: Error saving metadata: $e');
      rethrow; // Re-throw to be handled by the caller
    }
  }

  Future<String?> _getLocalTemplatePath(String firmwareVersion, String deviceType) async {
    if (_templatesDir == null) {
      await _initTemplatesDir();
    }
    final deviceTemplateDir = path.join(_templatesDir!, '${deviceType}_template');
    final directoryExists = await Directory(deviceTemplateDir).exists();
    if (!directoryExists) {
      return null;
    }

    final firmwareFolderName = firmwareVersion.replaceAll('.', '_');
    final firmwareFolderPath = path.join(deviceTemplateDir, firmwareFolderName);
    final fileName = '$firmwareFolderName.ino';
    final filePath = path.join(firmwareFolderPath, fileName);

    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  Future<List<String>> listAvailableFirmwareVersions(String deviceType) async {
    final result = <String>[];
    if (_templatesDir == null) {
      await _initTemplatesDir();
    }
    final deviceTypeDir = path.join(_templatesDir!, deviceType);
    final directory = Directory(deviceTypeDir);
    if (await directory.exists()) {
      await for (final file in directory.list()) {
        if (file is File && file.path.endsWith('.ino')) {
          final fileName = path.basename(file.path);
          final version = fileName.replaceAll('_', '.').replaceAll('.ino', '');
          result.add(version);
        }
      }
    }
    if (result.isEmpty) {
      result.addAll(['Không có firmware nào được lưu trữ']);
    }
    return result;
  }

  Future<bool> deleteTemplate(String firmwareVersion, String deviceType) async {
    final templatePath = await _getLocalTemplatePath(firmwareVersion, deviceType);
    if (templatePath != null) {
      final file = File(templatePath);
      if (await file.exists()) {
        await file.delete();
        final metadataFile = File(path.join(_templatesDir!, deviceType, 'metadata', '${firmwareVersion.replaceAll('.', '_')}.json'));
        if (await metadataFile.exists()) {
          await metadataFile.delete();
        }
        return true;
      }
    }
    return false;
  }
}
