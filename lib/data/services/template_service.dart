import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart'; // Thêm để tính hash
import 'dart:convert';

/// Service for managing firmware templates
class TemplateService {
  /// Base directory for storing firmware templates
  String? _templatesDir;

  /// Constructor initializes the templates directory
  TemplateService() {
    _initTemplatesDir();
  }

  /// Initialize the templates directory
  Future<void> _initTemplatesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    _templatesDir = path.join(appDir.path, 'firmware_templates');
    final dir = Directory(_templatesDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Get a firmware template - will use local if available, otherwise fetch from API
  Future<String?> getFirmwareTemplate(
      String firmwareVersion,
      String deviceType,
      String sourceCode, // Thêm sourceCode từ API
      String? hash, // Thêm hash để xác thực
      ) async {
    // Kiểm tra local trước
    final localPath = await _getLocalTemplatePath(firmwareVersion, deviceType);
    if (localPath != null && await File(localPath).exists()) {
      // Xác thực hash nếu có
      if (hash != null && await _verifyHash(localPath, hash)) {
        return localPath;
      }
    }

    // Nếu không có local hoặc hash không khớp, lưu mới từ sourceCode
    return await _saveTemplate(firmwareVersion, deviceType, sourceCode, hash);
  }

  /// Get the local path for a template if it exists
  Future<String?> _getLocalTemplatePath(
      String firmwareVersion,
      String deviceType,
      ) async {
    if (_templatesDir == null) {
      await _initTemplatesDir();
    }
    final deviceTypeDir = path.join(_templatesDir!, deviceType);
    final directoryExists = await Directory(deviceTypeDir).exists();
    if (!directoryExists) {
      return null;
    }
    final fileName = '${firmwareVersion.replaceAll('.', '_')}.ino';
    final filePath = path.join(deviceTypeDir, fileName);
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  /// Save firmware template from API sourceCode
  Future<String?> _saveTemplate(
      String firmwareVersion,
      String deviceType,
      String sourceCode,
      String? expectedHash,
      ) async {
    try {
      final deviceTypeDir = path.join(_templatesDir!, deviceType);
      final directory = Directory(deviceTypeDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final fileName = '${firmwareVersion.replaceAll('.', '_')}.ino';
      final filePath = path.join(deviceTypeDir, fileName);
      final file = File(filePath);

      // Xác thực hash trước khi lưu
      if (expectedHash != null) {
        final contentHash = md5.convert(utf8.encode(sourceCode)).toString();
        if (contentHash != expectedHash) {
          print('Hash mismatch for firmware $firmwareVersion');
          return null;
        }
      }

      // Lưu file
      await file.writeAsString(sourceCode);

      // Lưu metadata
      await _saveMetadata(firmwareVersion, deviceType, filePath);
      return filePath;
    } catch (e) {
      print('Error saving template: $e');
      return null;
    }
  }

  /// Verify file hash
  Future<bool> _verifyHash(String filePath, String expectedHash) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final contentHash = md5.convert(utf8.encode(content)).toString();
      return contentHash == expectedHash;
    } catch (e) {
      print('Error verifying hash: $e');
      return false;
    }
  }

  /// Save metadata for template
  Future<void> _saveMetadata(String firmwareVersion, String deviceType, String filePath) async {
    final metadataDir = path.join(_templatesDir!, deviceType, 'metadata');
    final metadataFile = File(path.join(metadataDir, '${firmwareVersion.replaceAll('.', '_')}.json'));
    final metadata = {
      'version': firmwareVersion,
      'deviceType': deviceType,
      'filePath': filePath,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await Directory(metadataDir).create(recursive: true);
    await metadataFile.writeAsString(json.encode(metadata));
  }

  /// Prepare a firmware template by replacing placeholders
  Future<String?> prepareFirmwareTemplate(
      String templatePath,
      String serialNumber,
      String deviceId,
      ) async {
    try {
      final templateFile = File(templatePath);
      if (!await templateFile.exists()) {
        print('Template file not found: $templatePath');
        return null;
      }
      String templateContent = await templateFile.readAsString();
      templateContent = templateContent.replaceAll('{{SERIAL_NUMBER}}', serialNumber);
      final tempDir = await getTemporaryDirectory();
      final compilePath = path.join(tempDir.path, 'compile_$serialNumber.ino');
      final compileFile = File(compilePath);
      await compileFile.writeAsString(templateContent);
      print('Template prepared for device $serialNumber');
      return compilePath; // Không xóa file tạm
    } catch (e) {
      print('Error preparing template: $e');
      return null;
    }
  }

  /// List all available firmware versions for a device type
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
      result.addAll(['1.0.0', '1.1.0', '2.0.0']);
    }
    return result;
  }

  /// Delete a firmware template
  Future<bool> deleteTemplate(String firmwareVersion, String deviceType) async {
    final templatePath = await _getLocalTemplatePath(firmwareVersion, deviceType);
    if (templatePath != null) {
      final file = File(templatePath);
      if (await file.exists()) {
        await file.delete();
        // Xóa metadata tương ứng
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