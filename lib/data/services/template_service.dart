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

  Future<String?> prepareFirmwareTemplate(
      String templatePath,
      String serialNumber,
      String deviceId,
      ) async {
    try {
      _logService.addLog(
        message: 'Starting template preparation for $serialNumber',
        level: LogLevel.info,
        step: ProcessStep.templatePreparation,
        deviceId: serialNumber,
        origin: 'system',
      );

      if (serialNumber.isEmpty) {
        _logService.addLog(
          message: 'Warning: Empty serial number passed for template replacement',
          level: LogLevel.warning,
          step: ProcessStep.templatePreparation,
          deviceId: serialNumber,
          origin: 'system',
        );
        serialNumber = 'DEFAULT_SERIAL';
      }

      final templateFile = File(templatePath);
      if (!await templateFile.exists()) {
        _logService.addLog(
          message: 'Template file not found: $templatePath',
          level: LogLevel.error,
          step: ProcessStep.templatePreparation,
          deviceId: serialNumber,
          origin: 'system',
        );
        return null;
      }

      String content = await templateFile.readAsString();
      _logService.addLog(
        message: 'Template file content length: ${content.length} bytes',
        level: LogLevel.info,
        step: ProcessStep.templatePreparation,
        deviceId: serialNumber,
        origin: 'system',
      );

      final tempDir = await getTemporaryDirectory();
      final compilePath = path.join(tempDir.path, 'firmware_${serialNumber}_${DateTime.now().millisecondsSinceEpoch}.ino');

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

      final definePattern = RegExp(r'#define\s+(\w+)\s+"{{([^}]+)}}"');
      content = content.replaceAllMapped(definePattern, (match) {
        final defineName = match.group(1);
        final placeholderName = match.group(2);
        final replaceValue = replacements[placeholderName];
        if (replaceValue != null) {
          _logService.addLog(
            message: 'Replaced #define $defineName with value: $replaceValue',
            level: LogLevel.info,
            step: ProcessStep.templatePreparation,
            deviceId: serialNumber,
            origin: 'system',
          );
          return '#define $defineName "$replaceValue"';
        }
        return match.group(0)!;
      });

      replacements.forEach((key, value) {
        final before = content;
        content = content.replaceAll('{{$key}}', value);
        if (before != content) {
          _logService.addLog(
            message: 'Replaced placeholder {{$key}} with value: $value',
            level: LogLevel.info,
            step: ProcessStep.templatePreparation,
            deviceId: serialNumber,
            origin: 'system',
          );
        }
      });

      final compileFile = File(compilePath);
      await compileFile.writeAsString(content);

      final processedContent = await compileFile.readAsString();
      if (processedContent.contains('{{')) {
        _logService.addLog(
          message: 'Warning: Found unreplaced placeholders in processed content',
          level: LogLevel.warning,
          step: ProcessStep.templatePreparation,
          deviceId: serialNumber,
          origin: 'system',
        );
        final placeholderPattern = RegExp(r'{{[^}]+}}');
        final matches = placeholderPattern.allMatches(processedContent);
        for (final match in matches) {
          _logService.addLog(
            message: 'Unreplaced placeholder: ${match.group(0)}',
            level: LogLevel.warning,
            step: ProcessStep.templatePreparation,
            deviceId: serialNumber,
            origin: 'system',
          );
        }
        return null;
      }

      _logService.addLog(
        message: 'Template processed successfully. Output file: $compilePath',
        level: LogLevel.success,
        step: ProcessStep.templatePreparation,
        deviceId: serialNumber,
        origin: 'system',
      );

      return compilePath;
    } catch (e, stackTrace) {
      _logService.addLog(
        message: 'Error preparing template: $e\n$stackTrace',
        level: LogLevel.error,
        step: ProcessStep.templatePreparation,
        deviceId: serialNumber,
        origin: 'system',
      );
      return null;
    }
  }

  Future<String?> saveFirmwareTemplate(
      String sourceCode,
      String firmwareVersion,
      String deviceType, {
        String? expectedHash,
      }) async {
    try {
      final deviceTemplateDir = path.join(_templatesDir!, '${deviceType}_template');
      final directory = Directory(deviceTemplateDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final firmwareFolderName = firmwareVersion.replaceAll('.', '_');
      final firmwareFolderPath = path.join(deviceTemplateDir, firmwareFolderName);
      await Directory(firmwareFolderPath).create(recursive: true);

      final fileName = '$firmwareFolderName.ino';
      final filePath = path.join(firmwareFolderPath, fileName);
      final file = File(filePath);

      if (expectedHash != null) {
        final contentHash = md5.convert(utf8.encode(sourceCode)).toString();
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

      await file.writeAsString(sourceCode);
      await _saveMetadata(firmwareVersion, deviceType, filePath);
      return filePath;
    } catch (e) {
      _logService.addLog(
        message: 'Error saving template: $e',
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );
      return null;
    }
  }

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
      result.addAll(['1.0.0', '1.1.0', '2.0.0']);
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