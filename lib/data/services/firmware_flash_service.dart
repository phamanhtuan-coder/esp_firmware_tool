import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_cli_service.dart';
import 'package:smart_net_firmware_loader/data/services/batch_service.dart';
import 'package:smart_net_firmware_loader/data/services/template_service.dart';
import 'package:smart_net_firmware_loader/data/services/usb_service.dart';
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
      final sketchFile = File(sketchPath);
      if (await sketchFile.exists()) {
        final content = await sketchFile.readAsString();
        final boardTypeMatch = RegExp(r'BOARD_TYPE: (\w+.*?)\s*\(ACTIVE\)').firstMatch(content);
        if (boardTypeMatch != null) {
          return boardTypeMatch.group(1)!.toLowerCase();
        }
      }
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
      // Debug info
      print('DEBUG: Starting firmware flash process');
      print(
        'DEBUG: Serial: $serialNumber, Device type: $deviceType, FW Version: $firmwareVersion',
      );
      print(
        'DEBUG: Local file: $localFilePath, Batch: $selectedBatch, Port: $selectedPort',
      );

      // Check port selection
      if (selectedPort == null || selectedPort.isEmpty) {
        onLog(
          LogEntry(
            message: '❌ Chưa chọn cổng COM để flash',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.flash,
            deviceId: serialNumber,
            origin: 'system',
          ),
        );
        return false;
      }

      // Prepare firmware
      onLog(
        LogEntry(
          message: '📝 Đang chuẩn bị firmware...',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.flash,
          deviceId: serialNumber,
          origin: 'system',
        ),
      );

      String? processedPath;

      // If using a local file
      if (localFilePath != null && localFilePath.isNotEmpty) {
        print('DEBUG: Processing local file: $localFilePath');
        onLog(
          LogEntry(
            message: '📂 Đang xử lý file local: $localFilePath',
            timestamp: DateTime.now(),
            level: LogLevel.info,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
            deviceId: serialNumber,
          ),
        );

        processedPath = await _templateService.prepareFirmwareTemplate(
          localFilePath,
          serialNumber,
          serialNumber,
          useQuotesForDefines: useQuotesForDefines,
        );
        print('DEBUG: Local file processed path: $processedPath');
      } else if (selectedBatch != null && firmwareVersion.isNotEmpty) {
        // Fetch từ server chỉ khi không có file local
        print(
          'DEBUG: Fetching firmware from server. Version: $firmwareVersion, Batch: $selectedBatch',
        );
        onLog(
          LogEntry(
            message:
                '🌐 Đang tải firmware phiên bản $firmwareVersion từ lô $selectedBatch',
            timestamp: DateTime.now(),
            level: LogLevel.info,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
            deviceId: serialNumber,
          ),
        );

        final sourceCode = await _batchService.fetchVersionFirmware(
          batchId: selectedBatch,
          firmwareId: firmwareVersion,
        );

        print('DEBUG: Fetched source code length: ${sourceCode?.length ?? 0}');

        if (sourceCode == null || sourceCode.isEmpty) {
          onLog(
            LogEntry(
              message: '❌ Không thể tải mã nguồn firmware',
              timestamp: DateTime.now(),
              level: LogLevel.error,
              step: ProcessStep.firmwareDownload,
              origin: 'system',
              deviceId: serialNumber,
            ),
          );
          return false;
        }

        print('DEBUG: Saving firmware template');
        final templatePath = await _templateService.saveFirmwareTemplate(
          sourceCode,
          firmwareVersion,
          deviceType,
        );
        print('DEBUG: Template path: $templatePath');

        if (templatePath == null) {
          onLog(
            LogEntry(
              message: '❌ Không thể lưu template firmware',
              timestamp: DateTime.now(),
              level: LogLevel.error,
              step: ProcessStep.firmwareDownload,
              origin: 'system',
              deviceId: serialNumber,
            ),
          );
          return false;
        }

        print('DEBUG: Preparing firmware template');
        processedPath = await _templateService.prepareFirmwareTemplate(
          templatePath,
          serialNumber,
          serialNumber,
          useQuotesForDefines: useQuotesForDefines,
        );
        print('DEBUG: Processed path: $processedPath');

        if (processedPath == null) {
          onLog(
            LogEntry(
              message: '❌ Không thể xử lý template firmware',
              timestamp: DateTime.now(),
              level: LogLevel.error,
              step: ProcessStep.templatePreparation,
              origin: 'system',
              deviceId: serialNumber,
            ),
          );
          return false;
        }

      } else {
        onLog(LogEntry(
          message: '❌ Cần chọn file local hoặc phiên bản firmware từ lô sản xuất',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
          deviceId: serialNumber,
        ));
        return false;
      }

      onLog(
        LogEntry(
          message: '✅ Đã xử lý template thành công',
          timestamp: DateTime.now(),
          level: LogLevel.success,
          step: ProcessStep.templatePreparation,
          origin: 'system',
          deviceId: serialNumber,
        ),
      );

      // Determine board type
      print('DEBUG: Getting board type from metadata');
      final boardType = await _getBoardTypeFromMetadata(processedPath!);
      final fqbn = _arduinoCliService.getBoardFqbn(boardType);
      print('DEBUG: Board type: $boardType, FQBN: $fqbn');

      // Check if Arduino CLI is available
      print('DEBUG: Checking if Arduino CLI is available');
      final cliAvailable = await _arduinoCliService.isCliAvailable();
      print('DEBUG: Arduino CLI available: $cliAvailable');

      if (!cliAvailable) {
        onLog(
          LogEntry(
            message:
                '❌ Arduino CLI không khả dụng. Vui lòng cài đặt hoặc kiểm tra lại.',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.firmwareCompile,
            deviceId: serialNumber,
            origin: 'system',
          ),
        );
        return false;
      }

      final coreInstalled = await _arduinoCliService.installCore(boardType);
      if (!coreInstalled) {
        onLog(LogEntry(
          message: '❌ Không thể cài đặt core cho board $boardType',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.installCore,
          origin: 'system',
        ));
        return false;
      }

      // Compile firmware
      onLog(
        LogEntry(
          message: '🔨 Đang biên dịch firmware...',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.firmwareCompile,
          deviceId: serialNumber,
          origin: 'system',
        ),
      );

      print('DEBUG: Starting compile sketch: $processedPath');
      final compiled = await _arduinoCliService.compileSketch(
        processedPath!,
        fqbn,
        onLog: (log) {
          print('DEBUG: Compile log: ${log.message}');
          onLog(log);
        },
      );

      print('DEBUG: Compile result: $compiled');
      if (!compiled) {
        onLog(
          LogEntry(
            message: '❌ Biên dịch firmware thất bại',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.firmwareCompile,
            deviceId: serialNumber,
            origin: 'system',
          ),
        );
        return false;
      }

      onLog(
        LogEntry(
          message: '✅ Biên dịch firmware thành công',
          timestamp: DateTime.now(),
          level: LogLevel.success,
          step: ProcessStep.firmwareCompile,
          deviceId: serialNumber,
          origin: 'system',
        ),
      );

      // Upload firmware
      onLog(
        LogEntry(
          message: '📤 Đang upload firmware...',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.flash,
          deviceId: serialNumber,
          origin: 'system',
        ),
      );

      print('DEBUG: Starting upload sketch to port: $selectedPort');
      final uploaded = await _arduinoCliService.uploadSketch(
        processedPath,
        selectedPort,
        fqbn,
        onLog: (log) {
          print('DEBUG: Upload log: ${log.message}');
          onLog(log);
        },
      );

      print('DEBUG: Upload result: $uploaded');
      if (!uploaded) {
        onLog(
          LogEntry(
            message: '❌ Upload firmware thất bại',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.flash,
            deviceId: serialNumber,
            origin: 'system',
          ),
        );
        return false;
      }

      onLog(
        LogEntry(
          message: '✅ Upload firmware thành công',
          timestamp: DateTime.now(),
          level: LogLevel.success,
          step: ProcessStep.flash,
          deviceId: serialNumber,
          origin: 'system',
        ),
      );

      return true;
    } catch (e) {
      onLog(
        LogEntry(
          message: '❌ Lỗi trong quá trình flash: $e',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.flash,
          deviceId: serialNumber,
          origin: 'system',
        ),
      );
      return false;
    }
  }

  Future<bool> _compileSketch({
    required String sketchPath,
    required String deviceType,
    void Function(LogEntry)? onLog,
  }) async {
    try {
      onLog?.call(
        LogEntry(
          message: 'Starting sketch compilation...',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.firmwareCompile,
          // Changed from compile
          origin: 'system',
        ),
      );

      final boardType = await _getBoardTypeFromMetadata(sketchPath);
      final fqbn = _arduinoCliService.getBoardFqbn(boardType);

      final result = await _arduinoCliService.compileSketch(sketchPath, fqbn);

      if (result) {
        onLog?.call(
          LogEntry(
            message: 'Compilation successful',
            timestamp: DateTime.now(),
            level: LogLevel.success,
            step: ProcessStep.firmwareCompile,
            // Changed from compile
            origin: 'system',
          ),
        );
        return true;
      } else {
        onLog?.call(
          LogEntry(
            message: 'Compilation failed',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.firmwareCompile,
            // Changed from compile
            origin: 'system',
          ),
        );
        return false;
      }
    } catch (e) {
      onLog?.call(
        LogEntry(
          message: 'Error during compilation: $e',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.firmwareCompile,
          // Changed from compile
          origin: 'system',
        ),
      );
      return false;
    }
  }
}
