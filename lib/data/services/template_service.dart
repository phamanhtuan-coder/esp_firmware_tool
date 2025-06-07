import 'dart:collection';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart'; // Thêm để tính hash
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';
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
      DebugLogger.d('📁 Đã tạo thư mục templates tại: ${dir.path}', className: 'TemplateService', methodName: '_initTemplatesDir');
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
    String boardType = 'esp32';

    final activeCommentPattern = RegExp(r'\/\/\s*BOARD_TYPE:\s*(\w+)\s*\(ACTIVE\)', multiLine: true);
    final activeMatches = activeCommentPattern.allMatches(content);

    if (activeMatches.isNotEmpty) {
      final foundType = activeMatches.first.group(1)?.toLowerCase();
      if (foundType != null) {
        boardType = normalizeDeviceType(foundType);
        DebugLogger.d('🔍 Đã tìm thấy loại board được đánh dấu ACTIVE: $boardType', className: 'TemplateService', methodName: 'extractBoardType');
        return boardType;
      }
    }

    final boardTypePattern = RegExp(r'(?:\/\/\s*)?BOARD_TYPE:\s*(\w+)', multiLine: true);
    final matches = boardTypePattern.allMatches(content);

    if (matches.isNotEmpty) {
      for (final match in matches) {
        final line = match.group(0);
        if (line != null && !line.trim().startsWith('//')) {
          final foundType = match.group(1)?.toLowerCase();
          if (foundType != null) {
            boardType = normalizeDeviceType(foundType);
            DebugLogger.d('🔍 Đã tìm thấy loại board đang hoạt động: $boardType', className: 'TemplateService', methodName: 'extractBoardType');
            break;
          }
        }
      }
    }

    if (boardType == 'esp32') {
      DebugLogger.d('⚠️ Không tìm thấy loại board đang hoạt động, các loại board đã tìm thấy:', className: 'TemplateService', methodName: 'extractBoardType');
      for (final match in matches) {
        DebugLogger.d('  - ${match.group(1)}', className: 'TemplateService', methodName: 'extractBoardType');
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
      await _cleanupTempFiles();

      DebugLogger.d('🔄 Bắt đầu chuẩn bị template', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');
      DebugLogger.d('📄 Đường dẫn template: $templatePath', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');
      DebugLogger.d('📱 Serial number: $serialNumber', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');
      DebugLogger.d('🆔 Device ID: $deviceId', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');

      if (serialNumber.isEmpty) {
        throw Exception('Serial number cannot be empty');
      }

      // Validate template file
      final templateFile = File(templatePath);
      DebugLogger.d('🔍 Kiểm tra tồn tại của file template', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');
      if (!await templateFile.exists()) {
        throw Exception('Không tìm thấy file template: $templatePath');
      }
      DebugLogger.d('✅ File template tồn tại', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');

      // Read template content
      DebugLogger.d('📖 Đọc nội dung template', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');
      String content = await templateFile.readAsString();
      DebugLogger.d('📝 Độ dài nội dung template: ${content.length}', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');

      // Get temporary directory for processed template
      DebugLogger.d('📁 Tạo thư mục tạm', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');
      final tempDir = await getTemporaryDirectory();
      final baseDir = Directory(path.join(tempDir.path, 'esp_firmware_tool'));
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final sketchName = 'firmware_${serialNumber}_${DateTime.now().millisecondsSinceEpoch}';
      final sketchDir = Directory(path.join(baseDir.path, sketchName));
      if (!await sketchDir.exists()) {
        await sketchDir.create(recursive: true);
      }
      DebugLogger.d('✅ Thư mục tạm đã được tạo tại: ${sketchDir.path}', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');

      // Process template with replacements
      DebugLogger.d('🔄 Xử lý các thay thế', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');
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
      DebugLogger.d('✅ Đã xử lý các định nghĩa', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');

      // Process remaining placeholders
      for (final entry in replacements.entries) {
        final placeholder = '{{${entry.key}}}';
        if (content.contains(placeholder)) {
          content = content.replaceAll(placeholder, entry.value);
          DebugLogger.d('🔄 Đã thay thế $placeholder bằng ${entry.value}', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');
        }
      }

      // Extract and validate board type
      final boardType = extractBoardType(content);
      DebugLogger.d('🔍 Đã phát hiện loại board: $boardType', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');

      // Write processed content
      final outputPath = path.join(sketchDir.path, '$sketchName.ino');
      DebugLogger.d('💾 Đang ghi nội dung đã xử lý vào: $outputPath', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');
      await File(outputPath).writeAsString(content);

      // Save metadata
      await _saveBoardTypeMetadata(sketchDir.path, boardType);

      DebugLogger.d('✅ Hoàn thành chuẩn bị template', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');
      DebugLogger.d('📝 File template đã được lưu tại: $outputPath', className: 'TemplateService', methodName: 'prepareFirmwareTemplate');

      return outputPath;
    } catch (e, stack) {
      DebugLogger.e('❌ Lỗi trong prepareFirmwareTemplate:',
        className: 'TemplateService',
        methodName: 'prepareFirmwareTemplate',
        error: e,
        stackTrace: stack);
      return null;
    }
  }

  Future<void> _saveBoardTypeMetadata(String sketchDir, String boardType) async {
    try {
      final metadataFile = File(path.join(sketchDir, 'board_metadata.json'));
      final metadata = {
        'boardType': boardType,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await metadataFile.writeAsString(json.encode(metadata));
      DebugLogger.d('✅ Đã lưu metadata board: $boardType', className: 'TemplateService', methodName: '_saveBoardTypeMetadata');
    } catch (e) {
      DebugLogger.e('❌ Lỗi lưu metadata board: $e',
        className: 'TemplateService',
        methodName: '_saveBoardTypeMetadata');
    }
  }


  String _processDefines(String content, String serialNumber, String deviceId) {
    _logService.addLog(
      message: 'Bắt đầu chuẩn bị template với serial number: $serialNumber',
      level: LogLevel.info,
      step: ProcessStep.templatePreparation,
      origin: 'system',
    );

    // Clean up serial number and device ID
    serialNumber = _cleanupIdentifier(serialNumber);
    deviceId = _cleanupIdentifier(deviceId);

    _logService.addLog(
      message: '» Đã chuẩn hóa thông tin:\n  - Serial: $serialNumber\n  - Device ID: $deviceId',
      level: LogLevel.info,
      step: ProcessStep.templatePreparation,
      origin: 'system',
    );

    // Check if the defines already exist in the content
    bool hasSerialNumberDefine = content.contains('#define SERIAL_NUMBER') ||
                                content.contains('#define serial_number');
    bool hasDeviceIdDefine = content.contains('#define DEVICE_ID') ||
                            content.contains('#define device_id');

    // Define patterns for different define formats
    final definePlaceholderPattern = RegExp(r'#define\s+(SERIAL_NUMBER|DEVICE_ID)\s+"?\{\{[A-Z_]+\}\}"?');
    final definePattern = RegExp(r'#define\s+(SERIAL_NUMBER|DEVICE_ID)\s+"?[^"\n\r]*"?');

    // First handle any existing #define statements with placeholders
    content = content.replaceAllMapped(definePlaceholderPattern, (match) {
      final defineName = match.group(1)!;
      final value = defineName == 'SERIAL_NUMBER' ? serialNumber : deviceId;
      _logService.addLog(
        message: '» Thay thế placeholder #define $defineName với giá trị "$value"',
        level: LogLevel.info,
        step: ProcessStep.templatePreparation,
        origin: 'system',
      );
      return '#define $defineName "$value"';
    });

    // Then handle any other #define statements
    content = content.replaceAllMapped(definePattern, (match) {
      final defineName = match.group(1)!;
      final value = defineName == 'SERIAL_NUMBER' ? serialNumber : deviceId;
      _logService.addLog(
        message: '» Cập nhật #define $defineName thành "$value"',
        level: LogLevel.info,
        step: ProcessStep.templatePreparation,
        origin: 'system',
      );
      return '#define $defineName "$value"';
    });

    // Add missing defines at the beginning
    if (!hasSerialNumberDefine) {
      content = '#define SERIAL_NUMBER "$serialNumber"\n$content';
      _logService.addLog(
        message: '» Thêm mới #define SERIAL_NUMBER "$serialNumber"',
        level: LogLevel.info,
        step: ProcessStep.templatePreparation,
        origin: 'system',
      );
    }

    if (!hasDeviceIdDefine) {
      content = '#define DEVICE_ID "$deviceId"\n$content';
      _logService.addLog(
        message: '» Thêm mới #define DEVICE_ID "$deviceId"',
        level: LogLevel.info,
        step: ProcessStep.templatePreparation,
        origin: 'system',
      );
    }

    // Handle remaining placeholders
    if (content.contains('{{SERIAL_NUMBER}}') || content.contains('{{DEVICE_ID}}')) {
      _logService.addLog(
        message: '» Xử lý các placeholder còn lại trong code',
        level: LogLevel.info,
        step: ProcessStep.templatePreparation,
        origin: 'system',
      );
      content = content.replaceAll('{{SERIAL_NUMBER}}', serialNumber);
      content = content.replaceAll('{{DEVICE_ID}}', deviceId);
    }

    _logService.addLog(
      message: 'Hoàn thành chuẩn bị template',
      level: LogLevel.success,
      step: ProcessStep.templatePreparation,
      origin: 'system',
    );

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
        DebugLogger.d('🔍 Content hash: $contentHash', className: 'TemplateService', methodName: 'saveFirmwareTemplate');
        DebugLogger.d('🔍 Expected hash: $expectedHash', className: 'TemplateService', methodName: 'saveFirmwareTemplate');

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
      DebugLogger.d('💾 Source code written to file: $filePath', className: 'TemplateService', methodName: 'saveFirmwareTemplate');

      // Save metadata in the same directory structure
      await _saveMetadata(firmwareVersion, deviceType, filePath);
      DebugLogger.d('✅ Metadata saved', className: 'TemplateService', methodName: 'saveFirmwareTemplate');

      _logService.addLog(
        message: 'Firmware template saved successfully',
        level: LogLevel.success,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );

      return filePath;
    } catch (e, stackTrace) {
      DebugLogger.e('❌ Error in saveFirmwareTemplate:',
        className: 'TemplateService',
        methodName: 'saveFirmwareTemplate',
        error: e,
        stackTrace: stackTrace);
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
      DebugLogger.d('✅ Metadata saved to: ${metadataFile.path}', className: 'TemplateService', methodName: '_saveMetadata');
    } catch (e) {
      DebugLogger.e('❌ Error saving metadata: $e',
        className: 'TemplateService',
        methodName: '_saveMetadata');
      rethrow;
    }
  }

  Future<void> _cleanupTempFiles() async {
    try {
      final systemTemp = Directory.systemTemp;
      final pattern = RegExp(r'esp_firmware_tool.*');

      await for (var entity in systemTemp.list()) {
        try {
          if (entity is Directory && pattern.hasMatch(path.basename(entity.path))) {
            DebugLogger.d('🗑️ Attempting to clean up temp directory: ${entity.path}', className: 'TemplateService', methodName: '_cleanupTempFiles');

            // Try to make files writable before deletion using platform-specific approach
            await for (var file in entity.list(recursive: true)) {
              try {
                if (file is File) {
                  await file.setLastModified(DateTime.now());
                  await Future.delayed(const Duration(milliseconds: 100));
                }
              } catch (e) {
                DebugLogger.e('❌ Failed to prepare file for deletion: $e',
                  className: 'TemplateService',
                  methodName: '_cleanupTempFiles');
              }
            }

            // Attempt deletion with retry logic
            bool deleted = false;
            int attempts = 0;
            while (!deleted && attempts < 3) {
              try {
                await entity.delete(recursive: true);
                deleted = true;
                DebugLogger.d('✅ Successfully cleaned up: ${entity.path}', className: 'TemplateService', methodName: '_cleanupTempFiles');
              } catch (e) {
                attempts++;
                if (attempts < 3) {
                  await Future.delayed(Duration(milliseconds: 500 * attempts));
                } else {
                  DebugLogger.e('❌ Failed to delete after 3 attempts: ${entity.path}',
                    className: 'TemplateService',
                    methodName: '_cleanupTempFiles');
                  _logService.addLog(
                    message: 'Warning: Could not clean up temporary directory: ${entity.path}. Error: $e',
                    level: LogLevel.warning,
                    step: ProcessStep.templatePreparation,
                    origin: 'system',
                  );
                }
              }
            }
          }
        } catch (e) {
          DebugLogger.e('❌ Error processing temp directory ${entity.path}: $e',
            className: 'TemplateService',
            methodName: '_cleanupTempFiles');
        }
      }
    } catch (e) {
      DebugLogger.e('❌ Non-critical error during temp cleanup: $e',
        className: 'TemplateService',
        methodName: '_cleanupTempFiles');
      _logService.addLog(
        message: 'Warning: Error during temporary file cleanup: $e',
        level: LogLevel.warning,
        step: ProcessStep.templatePreparation,
        origin: 'system',
      );
    }
  }
}
