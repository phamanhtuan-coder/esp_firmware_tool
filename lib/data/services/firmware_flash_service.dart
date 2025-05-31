import 'dart:async';

import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/data/services/arduino_cli_service.dart';
import 'package:esp_firmware_tool/data/services/batch_service.dart';
import 'package:esp_firmware_tool/data/services/template_service.dart';
import 'package:esp_firmware_tool/data/services/usb_service.dart';


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

  Future<void> flash({
    required String serialNumber,
    required String deviceType,
    required String firmwareVersion,
    required String? localFilePath,
    required String? selectedBatch,
    required void Function(LogEntry) onLog,
  }) async {
    onLog(LogEntry(
      message: '🔍 Checking USB port for device $serialNumber',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      step: ProcessStep.systemEvent,
      origin: 'system',
      deviceId: serialNumber,
    ));

    final port = await _usbService.getDevicePort(serialNumber);
    if (port == null) {
      onLog(LogEntry(
        message: '❌ No USB port found for device $serialNumber',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.systemEvent,
        origin: 'system',
        deviceId: serialNumber,
      ));
      return;
    }

    String? processedPath;

    // If a local file is provided, use it directly
    if (localFilePath != null) {
      onLog(LogEntry(
        message: '📂 Using local firmware file: $localFilePath',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
        deviceId: serialNumber,
      ));

      // Process the local file using the Dart method
      processedPath = await _templateService.prepareFirmwareTemplate(
        localFilePath,
        serialNumber,
        serialNumber, // Using serialNumber as deviceId for consistency
      );

      if (processedPath == null) {
        onLog(LogEntry(
          message: '❌ Failed to process local file template',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.templatePreparation,
          origin: 'system',
          deviceId: serialNumber,
        ));
        return;
      }
    } else {
      // No local file; fetch firmware from server
      if (firmwareVersion.isEmpty || selectedBatch == null) {
        onLog(LogEntry(
          message: '❌ Firmware version or batch not provided',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
          deviceId: serialNumber,
        ));
        return;
      }

      onLog(LogEntry(
        message: '🌐 Fetching firmware for version "$firmwareVersion" from batch "$selectedBatch"',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
        deviceId: serialNumber,
      ));

      final sourceCode = await _batchService.fetchVersionFirmware(batchId: selectedBatch);
      if (sourceCode == null || sourceCode.isEmpty) {
        onLog(LogEntry(
          message: '❌ No firmware source code returned from server',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
          deviceId: serialNumber,
        ));
        return;
      }

      // Save the fetched firmware as a template
      final templatePath = await _templateService.saveFirmwareTemplate(
        sourceCode,
        firmwareVersion,
        deviceType,
      );

      if (templatePath == null) {
        onLog(LogEntry(
          message: '❌ Failed to save firmware template',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
          deviceId: serialNumber,
        ));
        return;
      }

      // Process the template using the Dart method
      processedPath = await _templateService.prepareFirmwareTemplate(
        templatePath,
        serialNumber,
        serialNumber,
      );

      if (processedPath == null) {
        onLog(LogEntry(
          message: '❌ Failed to process template',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.templatePreparation,
          origin: 'system',
          deviceId: serialNumber,
        ));
        return;
      }
    }

    onLog(LogEntry(
      message: '✅ Template processed at: $processedPath',
      timestamp: DateTime.now(),
      level: LogLevel.success,
      step: ProcessStep.templatePreparation,
      origin: 'system',
      deviceId: serialNumber,
    ));

    final fqbn = _arduinoCliService.getBoardFqbn(
      deviceType.toLowerCase() == 'arduino uno r3' ? 'arduino_uno_r3' : deviceType,
    );

    onLog(LogEntry(
      message: '🛠 Compiling firmware...',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      step: ProcessStep.compile,
      origin: 'system',
      deviceId: serialNumber,
    ));

    final compiled = await _arduinoCliService.compileSketch(processedPath, fqbn);
    if (!compiled) {
      onLog(LogEntry(
        message: '❌ Compilation failed',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.compile,
        origin: 'system',
        deviceId: serialNumber,
      ));
      return;
    }

    onLog(LogEntry(
      message: '🚀 Uploading firmware to $port',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      step: ProcessStep.flash,
      origin: 'system',
      deviceId: serialNumber,
    ));

    final uploaded = await _arduinoCliService.uploadSketch(processedPath, port, fqbn);
    onLog(LogEntry(
      message: uploaded
          ? '✅ Firmware flashed successfully for $serialNumber'
          : '❌ Firmware flashing failed for $serialNumber',
      timestamp: DateTime.now(),
      level: uploaded ? LogLevel.success : LogLevel.error,
      step: ProcessStep.flash,
      origin: 'system',
      deviceId: serialNumber,
    ));
  }

}