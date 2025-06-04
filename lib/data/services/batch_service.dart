import 'dart:async';

import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_cli_service.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/api_client.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';

/// Service responsible for managing batches, devices, and firmware operations
class BatchService {
  final LogService _logService;
  final ArduinoCliService _arduinoCliService;
  final ApiClient _apiClient;

  // Track connections between device IDs and ports
  final Map<String, String> _devicePortMap = {};

  BatchService({
    required LogService logService,
    required ArduinoCliService arduinoCliService,
    required ApiClient apiClient,
  }) :
    _logService = logService,
    _arduinoCliService = arduinoCliService,
    _apiClient = apiClient;

  Future<List<Firmware>> fetchFirmwares(int templateId) async {
    try {
      _logService.addLog(
        message: 'Fetching firmware list for template $templateId',
        level: LogLevel.info,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );

      final response = await _apiClient.fetchFirmwareByTemplate(templateId);

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> firmwareData = response['data'] as List;
        final firmwares = firmwareData.map((json) => Firmware.fromJson(json)).toList();

        _logService.addLog(
          message: 'Found ${firmwares.length} firmware versions for template $templateId',
          level: LogLevel.success,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );

        return firmwares;
      } else {
        final String errorMessage = response['message'] ?? 'Unknown error occurred';
        _logService.addLog(
          message: 'Error fetching firmware list: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return [];
      }
    } catch (e) {
      _logService.addLog(
        message: 'Exception when fetching firmware list: $e',
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );
      return [];
    }
  }

  Future<String?> fetchVersionFirmware({
    required String batchId,
  }) async {
    try {
      _logService.addLog(
        message: 'Fetching firmware for batch $batchId',
        level: LogLevel.info,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );

      // TODO: Implement actual API call
      // For now, return a basic template for testing
      return '''
void setup() {
  Serial.begin(115200);
  Serial.println("Device {{SERIAL_NUMBER}} starting...");
}

void loop() {
  Serial.println("Hello from {{DEVICE_ID}}");
  delay(1000);
}
''';
    } catch (e) {
      _logService.addLog(
        message: 'Error fetching firmware: $e',
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );
      return null;
    }
  }

  Future<List<Device>> fetchDevices(String batchId) async {
    try {
      _logService.addLog(
        message: 'Đang tải danh sách thiết bị cho lô $batchId...',
        level: LogLevel.info,
        step: ProcessStep.deviceRefresh,
        origin: 'system',
      );

      final response = await _apiClient.get(
        '/production-tracking/info-need-upload-firmware/tracking/null/$batchId',
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> devicesData = response['data'] as List;
        final devices = devicesData.map((data) => Device.fromJson(data)).toList();

        // Remove duplicates based on device serial
        final uniqueDevices = <String, Device>{};
        for (var device in devices) {
          uniqueDevices[device.serial] = device;
        }

        _logService.addLog(
          message: 'Đã tải ${uniqueDevices.length} thiết bị cho lô $batchId',
          level: LogLevel.success,
          step: ProcessStep.deviceRefresh,
          origin: 'system',
        );

        return uniqueDevices.values.toList();
      } else {
        final String errorMessage = response['message'] ?? 'Unknown error occurred';
        _logService.addLog(
          message: 'Lỗi khi tải danh sách thiết bị: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.deviceRefresh,
          origin: 'system',
        );
        return [];
      }
    } catch (e) {
      _logService.addLog(
        message: 'Lỗi ngoại lệ khi tải thiết bị: $e',
        level: LogLevel.error,
        step: ProcessStep.deviceRefresh,
        origin: 'system',
      );
      return [];
    }
  }
}
