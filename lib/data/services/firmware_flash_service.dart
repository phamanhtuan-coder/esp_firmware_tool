import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/data/services/arduino_cli_service.dart';
import 'package:esp_firmware_tool/data/services/batch_service.dart';
import 'package:esp_firmware_tool/data/services/template_service.dart';
import 'package:esp_firmware_tool/data/services/usb_service.dart';
import 'package:path/path.dart' as path;

class FirmwareFlashService {
  final ArduinoCliService _arduinoCliService;
  final TemplateService _templateService;
  final BatchService _batchService;
  final UsbService _usbService;

  FirmwareFlashService(
      this._arduinoCliService,
      this._templateService,
      this._batchService,
      this._usbService,
      );

  /// Retrieve board type from metadata file created during template processing
  Future<String> _getBoardTypeFromMetadata(String sketchPath) async {
    try {
      final sketchDir = File(sketchPath).parent.path;
      final metadataFile = File(path.join(sketchDir, 'board_metadata.json'));

      if (await metadataFile.exists()) {
        final jsonData = json.decode(await metadataFile.readAsString());
        final boardType = jsonData['boardType'] as String?;
        if (boardType != null && boardType.isNotEmpty) {
          return boardType.toLowerCase();
        }
      }
    } catch (e) {
      print('DEBUG: Error reading board metadata: $e');
    }

    // Default to ESP32 if we can't determine
    return 'esp32';
  }

  Future<bool> flash({
    required String serialNumber,
    required String deviceType,
    required String firmwareVersion,
    String? localFilePath,
    String? selectedBatch,
    String? selectedPort,
    bool useQuotesForDefines = false,
    required void Function(LogEntry) onLog,
  }) async {
    try {
      // Check port selection
      if (selectedPort == null || selectedPort.isEmpty) {
        onLog(LogEntry(
          message: '❌ Chưa chọn cổng COM để flash',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.flash,
          deviceId: serialNumber,
          origin: 'system',
        ));
        return false;
      }

      // Prepare firmware
      onLog(LogEntry(
        message: '📝 Đang chuẩn bị firmware...',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        step: ProcessStep.flash,
        deviceId: serialNumber,
        origin: 'system',
      ));

      String? processedPath;

      // If using a local file
      if (localFilePath != null && localFilePath.isNotEmpty) {
        onLog(LogEntry(
          message: '📂 Đang xử lý file local: $localFilePath',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
          deviceId: serialNumber,
        ));

        processedPath = await _templateService.prepareFirmwareTemplate(
          localFilePath,
          serialNumber,
          serialNumber,
          useQuotesForDefines: useQuotesForDefines,
        );
      } else {
        // Using firmware version from server/batch
        if (selectedBatch == null) {
          onLog(LogEntry(
            message: '❌ Không có batch được chọn cho firmware version $firmwareVersion',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
            deviceId: serialNumber,
          ));
          return false;
        }

        onLog(LogEntry(
          message: '🌐 Đang tải firmware phiên bản $firmwareVersion từ lô $selectedBatch',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
          deviceId: serialNumber,
        ));

        final sourceCode = await _batchService.fetchVersionFirmware(batchId: selectedBatch);
        if (sourceCode == null || sourceCode.isEmpty) {
          onLog(LogEntry(
            message: '❌ Không thể tải mã nguồn firmware',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
            deviceId: serialNumber,
          ));
          return false;
        }

        final templatePath = await _templateService.saveFirmwareTemplate(
          sourceCode,
          firmwareVersion,
          deviceType,
        );

        if (templatePath == null) {
          onLog(LogEntry(
            message: '❌ Không thể lưu template firmware',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
            deviceId: serialNumber,
          ));
          return false;
        }

        processedPath = await _templateService.prepareFirmwareTemplate(
          templatePath,
          serialNumber,
          serialNumber,
          useQuotesForDefines: useQuotesForDefines,
        );
      }

      if (processedPath == null) {
        onLog(LogEntry(
          message: '❌ Không thể xử lý template firmware',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.templatePreparation,
          origin: 'system',
          deviceId: serialNumber,
        ));
        return false;
      }

      onLog(LogEntry(
        message: '✅ Đã xử lý template thành công',
        timestamp: DateTime.now(),
        level: LogLevel.success,
        step: ProcessStep.templatePreparation,
        origin: 'system',
        deviceId: serialNumber,
      ));

      // Determine board type
      final boardType = await _getBoardTypeFromMetadata(processedPath);
      final fqbn = _arduinoCliService.getBoardFqbn(boardType);

      // Compile firmware
      onLog(LogEntry(
        message: '🔨 Đang biên dịch firmware...',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        step: ProcessStep.compile,
        deviceId: serialNumber,
        origin: 'system',
      ));

      final compiled = await _arduinoCliService.compileSketch(processedPath, fqbn);
      if (!compiled) {
        onLog(LogEntry(
          message: '❌ Biên dịch firmware thất bại',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.compile,
          deviceId: serialNumber,
          origin: 'system',
        ));
        return false;
      }

      onLog(LogEntry(
        message: '✅ Biên dịch firmware thành công',
        timestamp: DateTime.now(),
        level: LogLevel.success,
        step: ProcessStep.compile,
        deviceId: serialNumber,
        origin: 'system',
      ));

      // Upload firmware
      onLog(LogEntry(
        message: '📤 Đang upload firmware...',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        step: ProcessStep.flash,
        deviceId: serialNumber,
        origin: 'system',
      ));

      final uploaded = await _arduinoCliService.uploadSketch(processedPath, selectedPort, fqbn);
      if (!uploaded) {
        onLog(LogEntry(
          message: '❌ Upload firmware thất bại',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.flash,
          deviceId: serialNumber,
          origin: 'system',
        ));
        return false;
      }

      onLog(LogEntry(
        message: '✅ Upload firmware thành công',
        timestamp: DateTime.now(),
        level: LogLevel.success,
        step: ProcessStep.flash,
        deviceId: serialNumber,
        origin: 'system',
      ));

      return true;

    } catch (e) {
      onLog(LogEntry(
        message: '❌ Lỗi trong quá trình flash: $e',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.flash,
        deviceId: serialNumber,
        origin: 'system',
      ));
      return false;
    }
  }
}
