import 'dart:async';

import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/api_client.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';

/// Service responsible for managing batches, devices, and firmware operations
class BatchService {
  final LogService _logService;
  final ApiClient _apiClient;

  BatchService({
    required LogService logService,
    required ApiClient apiClient,
  }) :
    _logService = logService,
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
    String? firmwareId,
  }) async {
    try {
      _logService.addLog(
        message: 'Fetching firmware for batch $batchId',
        level: LogLevel.info,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );

      if (firmwareId == null) {
        _logService.addLog(
          message: 'Error: Firmware ID is required',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return null;
      }

      final response = await _apiClient.get('/firmware/detail/$firmwareId');

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final sourceCode = data['file_path'] as String?;

        if (sourceCode == null || sourceCode.isEmpty) {
          _logService.addLog(
            message: 'Error: Source code is empty in firmware data',
            level: LogLevel.error,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
          );
          return null;
        }

        _logService.addLog(
          message: 'Successfully fetched firmware version ${data['version']}',
          level: LogLevel.success,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );

        return sourceCode;
      } else {
        final String errorMessage = response['message'] ?? 'Unknown error occurred';
        _logService.addLog(
          message: 'Error fetching firmware: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return null;
      }
    } catch (e) {
      _logService.addLog(
        message: 'Exception when fetching firmware: $e',
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
