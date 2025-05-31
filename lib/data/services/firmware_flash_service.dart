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

  Future<void> flash({
    required String serialNumber,
    required String deviceType,
    required String firmwareVersion,
    required String? localFilePath,
    required String? selectedBatch,
    required void Function(LogEntry) onLog,
    String? selectedPort,
    bool useQuotesForDefines = false, // Add parameter to control quotes in #define
    String? overrideBoardType, // Optional parameter to override auto-detected board type
  }) async {
    // Kiểm tra port được chọn trước tiên
    String? port = selectedPort;

    // Nếu không có port được chỉ định, tìm kiếm port từ UsbService
    if (port == null || port.isEmpty) {
      onLog(LogEntry(
        message: '🔍 Không có cổng được chọn, đang tìm cổng tự động cho thiết bị $serialNumber',
        timestamp: DateTime.now(),
        level: LogLevel.warning,
        step: ProcessStep.systemEvent,
        origin: 'system',
        deviceId: serialNumber,
      ));

      port = await _usbService.getDevicePort(serialNumber);
    } else {
      onLog(LogEntry(
        message: '✅ Sử dụng cổng đã chọn: $port',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        step: ProcessStep.systemEvent,
        origin: 'system',
        deviceId: serialNumber,
      ));
    }

    if (port == null || port.isEmpty) {
      onLog(LogEntry(
        message: '❌ Không tìm thấy cổng USB cho thiết bị $serialNumber',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.systemEvent,
        origin: 'system',
        deviceId: serialNumber,
      ));
      return;
    }

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
        useQuotesForDefines: useQuotesForDefines, // Pass the quote preference
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
        return;
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
        return;
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
        return;
      }

      processedPath = await _templateService.prepareFirmwareTemplate(
        templatePath,
        serialNumber,
        serialNumber,
        useQuotesForDefines: useQuotesForDefines, // Pass the quote preference
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
      return;
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
    final boardType = overrideBoardType ?? await _getBoardTypeFromMetadata(processedPath);
    final fqbn = _arduinoCliService.getBoardFqbn(boardType);

    onLog(LogEntry(
      message: '🛠 Đang biên dịch firmware...',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      step: ProcessStep.compile,
      origin: 'system',
      deviceId: serialNumber,
    ));

    final compiled = await _arduinoCliService.compileSketch(processedPath, fqbn);
    if (!compiled) {
      onLog(LogEntry(
        message: '❌ Biên dịch thất bại',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.compile,
        origin: 'system',
        deviceId: serialNumber,
      ));
      return;
    } else {
      onLog(LogEntry(
        message: '✅ Biên dịch thành công',
        timestamp: DateTime.now(),
        level: LogLevel.success,
        step: ProcessStep.compile,
        origin: 'system',
        deviceId: serialNumber,
      ));
    }

    onLog(LogEntry(
      message: '🚀 Đang nạp firmware vào cổng $port',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      step: ProcessStep.flash,
      origin: 'system',
      deviceId: serialNumber,
    ));

    final uploaded = await _arduinoCliService.uploadSketch(processedPath, port, fqbn);
    onLog(LogEntry(
      message: uploaded
          ? '✅ Nạp firmware thành công'
          : '❌ Nạp firmware thất bại',
      timestamp: DateTime.now(),
      level: uploaded ? LogLevel.success : LogLevel.error,
      step: ProcessStep.flash,
      origin: 'system',
      deviceId: serialNumber,
    ));
  }
}

